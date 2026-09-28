"""SoulSign desktop adapter over the pinned, vendored iPASide engine."""
import contextlib
import hashlib
import json
import logging
from logging.handlers import RotatingFileHandler
import msvcrt
import os
from pathlib import Path
import re
import shutil
import sys
from ipaside_engine import paths, gsa, device, apple_support, signing, refresh, sideload

os.environ['IPASIDE_CONNECTION'] = 'usb'

def redact(value):
    text = str(value)
    text = re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', '[Apple ID]', text)
    text = re.sub(r'(?i)(password|auth_token|GsIdmsToken|idms|token|secret|verification_code)\s*[=:]\s*\S+', r'\1=[hidden]', text)
    text = re.sub(r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{16}\b|\b[0-9a-fA-F]{40}\b', '[device]', text)
    return text

def logger():
    log = logging.getLogger('soulsign')
    if not log.handlers:
        handler = RotatingFileHandler(paths.data_dir()/'soulsign.log', maxBytes=2_000_000, backupCount=2, encoding='utf-8')
        handler.setFormatter(logging.Formatter('%(asctime)s %(message)s'))
        log.addHandler(handler)
        log.setLevel(logging.INFO)
    return log

def report(message):
    logger().info(redact(message))

@contextlib.contextmanager
def operation():
    with open(paths.data_dir()/'operation.lock', 'a+b') as file:
        file.seek(0, 2)
        if file.tell() == 0:
            file.write(b'0'); file.flush()
        file.seek(0)
        try:
            msvcrt.locking(file.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError:
            raise RuntimeError('另一个 SoulSign 操作正在运行，请稍后重试。') from None
        try:
            yield
        finally:
            file.seek(0)
            msvcrt.locking(file.fileno(), msvcrt.LK_UNLCK, 1)

def settings():
    file = paths.data_dir()/'desktop.json'
    return json.loads(file.read_text('utf-8')) if file.exists() else {'auto': False, 'within': 2}

def save_settings(data):
    file = paths.data_dir()/'desktop.json'
    temp = file.with_suffix('.tmp')
    temp.write_text(json.dumps(data), 'utf-8')
    os.replace(temp, file)

def diagnose():
    result = [f'Python {sys.version.split()[0]} / {64 if sys.maxsize > 2**32 else 32} 位']
    support = apple_support.status()
    result.append('Apple Mobile Device Service: ' + support['state'] + ' — ' + support['detail'])
    result.append('iTunes 注册信息：' + ('已检测到 ' + str(support.get('itunes_version') or '') if support.get('itunes_installed') else '未检测到（Apple Devices 也可提供设备服务）'))
    try:
        signing.resolve_zsign()
        result.append('zsign: 已就绪')
    except Exception as exc:
        result.append('zsign: ' + str(exc))
    devices = []
    try:
        devices = [x for x in device.list_devices() if str(x.get('connection_type')).upper() == 'USB']
    except Exception as exc:
        result.append('USB 枚举失败: ' + str(exc))
    if not devices:
        result.append('未检测到 USB iPhone：连接数据线、解锁手机并点“信任”。')
    for item in devices:
        try:
            info = device.get_device_info(item['serial'])
            result.append(f"{info.get('DeviceName', 'iPhone')} / iOS {info.get('ProductVersion', '?')}：Trust 验证成功")
        except Exception as exc:
            result.append('Trust 未验证成功：解锁手机并点“信任”，然后重新检测。' + str(exc))
    return result, devices

def cache_ipa(source):
    source = Path(source).resolve()
    if not source.is_file() or source.suffix.lower() != '.ipa':
        raise ValueError('请选择有效 IPA 文件。')
    from ipaside_engine import ipa
    ipa.inspect(str(source))
    with source.open('rb') as file:
        digest = hashlib.file_digest(file, 'sha256').hexdigest()
    folder = paths.data_dir()/'originals'
    folder.mkdir(exist_ok=True)
    target = folder/(digest + '.ipa')
    if not target.exists():
        shutil.copyfile(source, target)
    return str(target)

def install(source, email, udid, progress):
    if not email or not udid:
        raise ValueError('请先登录并选择 Apple ID 和 USB 设备。')
    signing.resolve_zsign()
    cached = cache_ipa(source)
    with gsa.acting_as(email):
        # Free-account mode: extensions are stripped, as in the upstream default.
        return sideload.run_sideload(cached, udid, on_progress=progress)

def renew(all_apps=False, bundle_id=None, progress=None):
    entries = refresh.records() if all_apps else refresh.due(float(settings().get('within', 2)))
    if bundle_id:
        entries = [x for x in refresh.records() if x['bundle_id'] == bundle_id]
    results = []
    for entry in entries:
        try:
            sideload.refresh_record(entry, on_progress=progress)
            results.append(f"{entry['bundle_id']}: 续签成功")
        except Exception as exc:
            results.append(f"{entry['bundle_id']}: 失败 — {redact(exc)}")
    return results or ['没有需要续签的应用。']
