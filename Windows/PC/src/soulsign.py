"""SoulSign PC 1.3.0 native Tk desktop; worker threads never access Tk."""
import json
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import ttk, filedialog, simpledialog, messagebox
from tkinter.scrolledtext import ScrolledText
import core
import phone_pairing
from ipaside_engine import gsa, paths, refresh

ROOT = Path(getattr(sys, '_MEIPASS', Path(__file__).resolve().parent.parent))

class App:
    def __init__(self, root):
        self.root = root
        self.busy = False
        self.events = queue.Queue()
        self.device_rows = []
        self.secrets = []
        root.title('SoulSign PC 1.3.1 · 安装与配对')
        root.geometry('980x760')
        root.minsize(780, 620)
        self.icon = tk.PhotoImage(file=str(ROOT/'assets/SoulSign.png'))
        root.iconphoto(True, self.icon)
        style = ttk.Style(root)
        style.theme_use('clam')
        style.configure('TButton', padding=7)
        style.configure('TLabel', font=('Microsoft YaHei UI', 10))
        outer = ttk.Frame(root, padding=16); outer.pack(fill='both', expand=True)
        ttk.Label(outer, text='SoulSign PC', font=('Microsoft YaHei UI', 23, 'bold')).pack(anchor='w')
        ttk.Label(outer, text='① 安装 IPA 到手机    ② 生成配对信息并写入 SoulSign').pack(anchor='w', pady=(0, 10))
        row = ttk.Frame(outer); row.pack(fill='x')
        ttk.Button(row, text='重新检测环境 / Trust', command=self.detect).pack(side='left')
        self.device = ttk.Combobox(row, state='readonly', width=47); self.device.pack(side='left', padx=8)
        self.state = tk.StringVar(value='就绪')
        ttk.Label(row, textvariable=self.state).pack(side='right')
        self.tabs = ttk.Notebook(outer); self.tabs.pack(fill='both', expand=True, pady=10)
        install = ttk.Frame(self.tabs, padding=12)
        library = ttk.Frame(self.tabs, padding=12)
        diagnostics = ttk.Frame(self.tabs, padding=12)
        logs = ttk.Frame(self.tabs, padding=12)
        pair = ttk.Frame(self.tabs, padding=12)
        for panel, title in [(install, '① 安装 IPA'), (pair, '② 配对手机'), (library, '应用 / 自动续签'), (diagnostics, '首次检测'), (logs, '运行日志')]:
            self.tabs.add(panel, text=title)
        self.advanced_panels = [library, diagnostics, logs]
        for panel in self.advanced_panels: self.tabs.hide(panel)
        ttk.Button(outer,text='显示 / 隐藏高级功能（续签、检测、日志）',command=self.toggle_advanced).pack(anchor='e')
        ttk.Label(pair,text='USB 配对不需要登录 Apple ID。请保持 iPhone 解锁，并已信任此电脑。\nUDID 由 PC 自动读取并随文件发送，无需在手机手填。',justify='left').pack(anchor='w',pady=8)
        ttk.Button(pair,text='查找手机中已安装的 SoulSign',command=self.find_phone_apps).pack(anchor='w',pady=8)
        self.phone_app = ttk.Combobox(pair,state='readonly',width=75); self.phone_app.pack(fill='x',pady=8)
        ttk.Button(pair,text='生成配对文件并写入 SoulSign',command=self.pair_phone).pack(anchor='w',pady=8)
        ttk.Button(pair,text='导出配对文件（手动导入备用）',command=self.export_pairing).pack(anchor='w',pady=8)
        ttk.Button(pair,text='复制当前设备 UDID',command=self.copy_udid).pack(anchor='w',pady=8)
        self.pair_status = tk.StringVar(value='写入后，在手机打开 SoulSign → 我的 → 设备 → 检查配对状态。\n“已写入”不等于手机端连接已验证；VPN/隧道仍按手机端提示配置。')
        ttk.Label(pair,textvariable=self.pair_status,wraplength=800,justify='left').pack(anchor='w',pady=12)
        self.diagnostics = ScrolledText(diagnostics, wrap='word'); self.diagnostics.pack(fill='both', expand=True)
        ttk.Label(install, text='签名账号').pack(anchor='w')
        row = ttk.Frame(install); row.pack(fill='x', pady=8)
        self.account = ttk.Combobox(row, state='readonly', width=42); self.account.pack(side='left')
        ttk.Button(row, text='添加 / 重新登录', command=self.login).pack(side='left', padx=8)
        ttk.Button(row, text='移除所选账号', command=self.logout).pack(side='left')
        ttk.Label(install, text='IPA 文件（可以将文件拖到下面的输入框）').pack(anchor='w', pady=(16, 5))
        self.ipa = tk.StringVar()
        entry = ttk.Entry(install, textvariable=self.ipa); entry.pack(fill='x')
        if hasattr(entry, 'drop_target_register'):
            entry.drop_target_register('DND_Files')
            entry.dnd_bind('<<Drop>>', self.drop)
        ttk.Button(install, text='选择 IPA…', command=self.choose).pack(anchor='w', pady=10)
        ttk.Label(install, text='默认按免费账号模式移除 App 扩展 / Watch 内容。\n原始 IPA 自动缓存，供后续续签使用。\n首次登录需联网获取 Anisette 组件；密码不写入文件。', justify='left').pack(anchor='w', pady=15)
        ttk.Button(install, text='签名并安装到所选 iPhone', command=self.install).pack(anchor='w', pady=8)
        self.apps = ttk.Treeview(library, columns=('name','expiry','account'), show='headings', height=10)
        for column, label, width in [('name','应用 / Bundle ID',360),('expiry','到期时间',170),('account','签名账号',210)]:
            self.apps.heading(column, text=label); self.apps.column(column, width=width)
        self.apps.pack(fill='both', expand=True)
        row = ttk.Frame(library); row.pack(fill='x', pady=8)
        ttk.Button(row, text='刷新列表', command=self.reload).pack(side='left')
        ttk.Button(row, text='续签所选', command=self.renew_selected).pack(side='left', padx=8)
        ttk.Button(row, text='一键刷新全部', command=lambda:self.start(lambda:core.renew(True, progress=self.progress), self.renewed)).pack(side='left')
        cfg = core.settings()
        self.auto = tk.BooleanVar(value=cfg.get('auto', False))
        ttk.Checkbutton(library, text='程序运行时自动续签（每小时检查）', variable=self.auto, command=self.save_auto).pack(anchor='w')
        row = ttk.Frame(library); row.pack(fill='x', pady=8)
        ttk.Label(row, text='提前天数').pack(side='left')
        self.within = ttk.Combobox(row, values=('1','2','3'), state='readonly', width=5)
        self.within.set(str(cfg.get('within', 2))); self.within.pack(side='left', padx=8)
        self.within.bind('<<ComboboxSelected>>', lambda e:self.save_auto())
        ttk.Button(row, text='启用 Windows 后台计划', command=lambda:self.schedule(False)).pack(side='left')
        ttk.Button(row, text='关闭后台计划', command=lambda:self.schedule(True)).pack(side='left', padx=8)
        ttk.Label(library, text='后台计划：当前用户登录后每小时检查；电脑须开机、iPhone 须通过 USB 连接。\n账号失效或需要 2FA 时，请回到本窗口重新登录。').pack(anchor='w')
        row = ttk.Frame(logs); row.pack(fill='x')
        ttk.Button(row, text='查看 / 刷新日志', command=self.load_log).pack(side='left')
        ttk.Button(row, text='复制日志', command=self.copy_log).pack(side='left', padx=8)
        ttk.Button(row, text='清除日志', command=self.clear_log).pack(side='left')
        self.logbox = ScrolledText(logs, wrap='word'); self.logbox.pack(fill='both', expand=True, pady=8)
        ttk.Label(outer, text='首次安装后：按 iPhone 提示信任开发者；若系统要求，请开启开发者模式。').pack(anchor='w')
        root.protocol('WM_DELETE_WINDOW', self.close)
        root.after(100, self.poll)
        root.after(200, self.detect)
        root.after(60_000, self.auto_tick)
        if len(sys.argv) > 1 and sys.argv[1].lower().endswith('.ipa'):
            self.ipa.set(sys.argv[1])

    def safe(self, text):
        for secret in self.secrets:
            if secret: text = str(text).replace(secret, '[hidden]')
        return core.redact(text)

    def toggle_advanced(self):
        show = self.tabs.tab(self.advanced_panels[0],'state') == 'hidden'
        for panel in self.advanced_panels:
            if show: self.tabs.add(panel)
            else: self.tabs.hide(panel)

    def find_phone_apps(self):
        udid = self.device.get()
        def done(result):
            self.phone_app['values'] = list(result)
            self.phone_app.set(next(iter(result)) if len(result)==1 else '')
            self.pair_status.set('请选择目标 SoulSign，然后生成并写入。' if result else '未找到 SoulSign，请先安装手机端 IPA。')
        self.start(lambda:phone_pairing.targets(udid),done)

    def pair_phone(self):
        udid, bundle = self.device.get(), self.phone_app.get()
        if not bundle: messagebox.showinfo('配对','请先查找并选择手机中的 SoulSign。'); return
        self.start(lambda:phone_pairing.deliver(udid,bundle), self.pair_done)

    def pair_done(self,result):
        self.pair_status.set(result); self.note(result); messagebox.showinfo('配对文件',result)

    def export_pairing(self):
        udid = self.device.get()
        if not udid: messagebox.showinfo('配对','请先连接并选择 iPhone。'); return
        filename = filedialog.asksaveasfilename(initialfile='SoulSignPairing.mobiledevicepairing',defaultextension='.mobiledevicepairing',filetypes=[('配对文件','*.mobiledevicepairing')])
        if filename: self.start(lambda:phone_pairing.export(udid,filename),self.pair_done)

    def copy_udid(self):
        if self.device.get():
            self.root.clipboard_clear(); self.root.clipboard_append(self.device.get())

    def note(self, text):
        core.report(self.safe(text)); self.load_log()

    def start(self, fn, done=None):
        if self.busy:
            messagebox.showinfo('SoulSign', '当前操作尚未完成。'); return
        self.busy = True; self.state.set('处理中…')
        def worker():
            try:
                with core.operation(): result = fn()
                self.events.put(('done', done, result))
            except Exception as exc:
                self.events.put(('error', None, self.safe(str(exc))))
        threading.Thread(target=worker, daemon=True).start()

    def poll(self):
        try:
            while True:
                kind, callback, value = self.events.get_nowait()
                if kind == 'progress': self.state.set(value); self.note(value); continue
                self.busy = False; self.state.set('就绪' if kind == 'done' else '操作失败')
                if kind == 'error':
                    self.note(value); self.secrets.clear(); messagebox.showerror('操作失败', value)
                elif callback:
                    try: callback(value)
                    except Exception as exc: self.note(str(exc)); messagebox.showerror('SoulSign', self.safe(str(exc)))
        except queue.Empty: pass
        self.root.after(100, self.poll)

    def progress(self, phase, percent=None, step=None):
        self.events.put(('progress', None, self.safe(f'{phase} {percent if percent is not None else ""} {step or ""}')))

    def detect(self): self.start(core.diagnose, self.detected)

    def detected(self, result):
        lines, self.device_rows = result
        self.diagnostics.delete('1.0','end'); self.diagnostics.insert('end', '\n\n'.join(lines))
        old = self.device.get()
        values = [x['serial'] for x in self.device_rows]
        self.device['values'] = values
        self.device.set(old if old in values else (values[0] if len(values)==1 else ''))
        self.note('\n'.join(lines)); self.reload()

    def reload(self):
        if self.busy: return
        def read(): return gsa.accounts(), refresh.records()
        self.start(read, self.reloaded)

    def reloaded(self, value):
        accounts, entries = value
        current = self.account.get()
        values = [x['email'] for x in accounts['accounts']]
        self.account['values'] = values
        self.account.set(current if current in values else (accounts.get('active') or (values[0] if values else '')))
        self.apps.delete(*self.apps.get_children())
        for entry in entries:
            self.apps.insert('', 'end', iid=entry['bundle_id'], values=(entry.get('name') or entry['bundle_id'], entry.get('expires_at','未知'), entry.get('account') or entry.get('email') or entry.get('team_id','')))

    def login(self):
        if self.busy: return
        email = simpledialog.askstring('Apple ID', '输入 Apple ID 邮箱：', parent=self.root)
        if not email: return
        password = simpledialog.askstring('Apple ID', '输入 Apple ID 密码（仅在内存中使用）：', show='*', parent=self.root)
        if not password: return
        email = email.strip(); self.secrets = [password]
        def finish(result):
            if result.get('status') == '2fa_required':
                code = simpledialog.askstring('双重认证', '请输入可信设备或短信收到的 6 位验证码：', parent=self.root)
                if not code:
                    self.secrets.clear(); self.start(lambda:gsa._clear_pending()); return
                if not code.strip().isdigit() or len(code.strip()) != 6:
                    self.secrets.clear(); messagebox.showerror('验证码', '请输入 6 位数字后重新登录。'); return
                self.secrets.append(code.strip())
                self.start(lambda:gsa.complete_2fa(email,password,code.strip()), self.logged_in)
            else: self.logged_in(result)
        self.start(lambda:gsa.begin_login(email,password), finish)

    def logged_in(self, result):
        self.secrets.clear()
        if result.get('status') != 'authenticated': raise ValueError('登录未完成')
        gsa._clear_pending(); self.note('账号登录成功。'); self.reload()

    def logout(self):
        email = self.account.get()
        if email and not self.busy:
            self.start(lambda:gsa.logout(email), lambda _:self.reload())

    def choose(self):
        name = filedialog.askopenfilename(filetypes=[('iOS 应用','*.ipa')])
        if name: self.ipa.set(name)

    def drop(self, event):
        files = self.root.tk.splitlist(event.data)
        if len(files)==1 and files[0].lower().endswith('.ipa'): self.ipa.set(files[0])
        else: messagebox.showerror('IPA', '请每次拖入一个 IPA 文件。')
        return event.action

    def install(self):
        source, email, udid = self.ipa.get(), self.account.get(), self.device.get()
        self.start(lambda:core.install(source,email,udid,self.progress), lambda _:self.installed())

    def installed(self):
        self.note('安装成功。'); messagebox.showinfo('SoulSign', '安装成功。安装的是 SoulSign 时，请继续到“② 配对手机”生成并写入配对文件。'); self.reload()

    def renew_selected(self):
        selected = self.apps.selection()
        if selected: self.start(lambda:core.renew(bundle_id=selected[0], progress=self.progress), self.renewed)

    def renewed(self, results):
        self.note('\n'.join(results)); messagebox.showinfo('续签结果', '\n'.join(results)); self.reload()

    def save_auto(self):
        core.save_settings({'auto':self.auto.get(), 'within':int(self.within.get())})

    def auto_tick(self):
        if self.auto.get() and not self.busy:
            self.start(lambda:core.renew(progress=self.progress), lambda result:self.note('\n'.join(result)))
        self.root.after(3_600_000, self.auto_tick)

    def schedule(self, remove):
        script = ROOT/'scripts/task.ps1'
        frozen = getattr(sys, 'frozen', False)
        executable = sys.executable if frozen else str(Path(sys.executable).with_name('pythonw.exe'))
        entry = '' if frozen else str(Path(__file__).resolve())
        args = ['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',str(script),'-Executable',executable]
        if entry: args += ['-Entry', entry]
        if remove: args.append('-Remove')
        def run():
            result = subprocess.run(args,capture_output=True, text=True,encoding='utf-8',errors='replace',creationflags=0x08000000)
            if result.returncode: raise RuntimeError(result.stderr or result.stdout)
            return result.stdout
        def done(_):
            self.auto.set(not remove); self.save_auto()
            self.note('后台计划已关闭。' if remove else '后台计划已启用（用户登录期间每小时检查）。')
        self.start(run,done)

    def load_log(self):
        file = paths.data_dir()/'soulsign.log'
        text = file.read_text('utf-8',errors='replace') if file.exists() else ''
        self.logbox.delete('1.0','end'); self.logbox.insert('end',text); self.logbox.see('end')

    def copy_log(self):
        self.root.clipboard_clear(); self.root.clipboard_append(self.logbox.get('1.0','end-1c'))

    def clear_log(self):
        if self.busy: return
        log = core.logger()
        for handler in list(log.handlers): handler.close(); log.removeHandler(handler)
        for file in paths.data_dir().glob('soulsign.log*'): file.unlink(missing_ok=True)
        self.load_log()

    def close(self):
        if self.busy:
            messagebox.showinfo('SoulSign', '请等待当前操作完成后退出，避免中断签名或安装。'); return
        self.root.destroy()

def main():
    if '--self-test' in sys.argv:
        from secure_store import crypt
        from ipaside_engine import signing
        from pymobiledevice3.services.installation_proxy import InstallationProxyService
        from pymobiledevice3.services.afc import AfcService
        from pymobiledevice3.remote.tunnel_service import RemotePairingLockdownService
        from anisette import Anisette
        from unicorn import Uc, UC_ARCH_ARM64, UC_MODE_ARM
        Uc(UC_ARCH_ARM64, UC_MODE_ARM)
        assert crypt(crypt(b'SoulSign self test'), True) == b'SoulSign self test'
        result = subprocess.run([signing.resolve_zsign(), '-v'], capture_output=True, check=True)
        core.report('Self-test PASS: DPAPI, Anisette imports, Unicorn, AFC, InstallationProxy, zsign ' + result.stdout.decode(errors='replace'))
        return
    if '--background' in sys.argv:
        if core.settings().get('auto'):
            try:
                with core.operation():
                    for result in core.renew(): core.report(result)
            except Exception as exc: core.report(exc)
        return
    from tkinterdnd2 import TkinterDnD
    root = TkinterDnD.Tk()
    App(root)
    if '--smoke-test' in sys.argv: root.after(1500, root.destroy)
    root.mainloop()

if __name__ == '__main__':
    if '--self-test' in sys.argv or '--smoke-test' in sys.argv:
        try: main()
        except Exception:
            import traceback
            core.report(traceback.format_exc())
            sys.exit(1)
    else:
        main()
