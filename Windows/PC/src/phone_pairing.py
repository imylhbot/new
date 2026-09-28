"""SoulSign-specific USB pairing delivery, matched to the iOS inbox contract."""
import plistlib
from pathlib import Path
from ipaside_engine import apps, device, pairing

CONSUMER = pairing.PairingConsumer('soulsign', 'SoulSign',
    'SoulSignPairing.mobiledevicepairing', ('/Documents',), False,
    ('com.mjorb.soulsign', 'com.mjorb.seal'))

def targets(udid):
    if not udid: raise ValueError('请先选择 USB iPhone。')
    installed = apps.list_installed(udid)
    return {bid: meta for bid, meta in installed.items()
            if CONSUMER.matches(bid) or str(meta.get('name','')).casefold() == 'soulsign'}

def prepare(udid):
    if not udid: raise ValueError('请先选择 USB iPhone。')
    info = device.get_device_info(udid)
    actual = info.get('UniqueDeviceID')
    if not actual or pairing._folded_udid(actual) != pairing._folded_udid(udid):
        raise ValueError('无法验证当前 USB 设备的 UDID，请重新检测。')
    version = str(info.get('ProductVersion',''))
    if not version: raise ValueError('无法读取 iOS 版本，未生成配对文件。')
    major = int(version.split('.')[0])
    if major >= 17:
        # Do not silently downgrade after failure: iOS chooses its tunnel by key type.
        pairing.ensure_remote_pairing(udid, udid)
    record = pairing.payload_record(udid)
    pairing._reject_foreign_udid(record, udid)
    record['UDID'] = actual
    if major >= 17 and not pairing.has_rppairing_keys(record):
        raise ValueError('RemotePairing 密钥生成失败，未写入手机。请解锁并重新信任电脑。')
    if major < 17 and not pairing.has_lockdown_keys(record):
        raise ValueError('USB 配对证书缺失，请重新信任电脑。')
    return plistlib.dumps(record, fmt=plistlib.FMT_XML), info

def deliver(udid, bundle_id):
    if bundle_id not in targets(udid):
        raise ValueError('目标 SoulSign 未安装或选择已失效，请重新查找。')
    payload, info = prepare(udid)
    result = pairing.deliver_to_app(bundle_id,udid,udid,consumer=CONSUMER,payload=payload)
    if not result.get('placed'):
        raise RuntimeError('配对文件写入失败：' + str(result.get('error','未知错误')) + '\n可改用“导出文件”，再通过 iTunes 文件共享导入。')
    return '文件已写入 SoulSign。请在手机打开/重新进入 SoulSign → 我的 → 设备 → 检查配对状态。\n手机端尚需验证本地连接；PC 不会把文件写入成功当作已激活。'

def export(udid, filename):
    payload, info = prepare(udid)
    Path(filename).write_bytes(payload)
    return '已导出配对文件（含当前设备 UDID）。通过 iTunes 文件共享放入 SoulSign，或传到手机“文件”后手动导入。不要公开此文件。'
