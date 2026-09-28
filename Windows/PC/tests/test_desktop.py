import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'src'))
import core
from secure_store import crypt, ProtectedPath, MAGIC
from ipaside_engine import gsa, paths

class DesktopTests(unittest.TestCase):
    def setUp(self):
        self.data = Path(__file__).resolve().parent/'scratch'
        self.data.mkdir(exist_ok=True)

    def test_dpapi_roundtrip(self):
        secret = b'example-account-token'
        encrypted = crypt(secret)
        self.assertNotIn(secret, encrypted)
        self.assertEqual(crypt(encrypted, True), secret)

    def test_account_storage_and_switch(self):
        with patch.object(paths, 'data_dir', return_value=self.data):
            for email in ('first@example.test','second@example.test'):
                gsa._save_account(email, {'adsid':'123'}, {'token':'not-real','expiry':123})
            self.assertEqual(len(gsa.accounts()['accounts']),2)
            gsa.use_account('first@example.test')
            self.assertEqual(gsa.load_session()['email'],'first@example.test')
            for file in paths.accounts_dir().glob('*.json'):
                self.assertIsInstance(file, ProtectedPath)
                self.assertTrue(Path(file).read_bytes().startswith(MAGIC))
                self.assertNotIn(b'not-real', Path(file).read_bytes())
            gsa.logout()

    def test_refresh_keeps_going_after_failure(self):
        entries = [{'bundle_id':'a'},{'bundle_id':'b'}]
        with patch.object(core.refresh,'records',return_value=entries), patch.object(core.sideload,'refresh_record',side_effect=[ValueError('offline'),{}]) as run:
            result = core.renew(True)
            self.assertIn('失败',result[0]); self.assertIn('成功',result[1])
            self.assertEqual(run.call_count,2)

    def test_install_requires_explicit_account_device(self):
        with self.assertRaises(ValueError): core.install('example.ipa','','',None)

    def test_install_uses_selected_account(self):
        with patch.object(core.signing,'resolve_zsign'), patch.object(core,'cache_ipa',return_value='cached.ipa'), patch.object(core.gsa,'acting_as') as acting, patch.object(core.sideload,'run_sideload') as run:
            core.install('input.ipa','first@example.test','chosen-device',None)
            acting.assert_called_once_with('first@example.test')
            self.assertEqual(run.call_args.args,('cached.ipa','chosen-device'))

    def test_redaction(self):
        text = core.redact('alice@example.com token=abc password=xyz 00008030-001234567890ABCD')
        for secret in ('alice@example.com','abc','xyz','001234567890ABCD'): self.assertNotIn(secret,text)

    def test_process_lock(self):
        with patch.object(paths,'data_dir',return_value=self.data):
            with core.operation():
                with self.assertRaises(RuntimeError):
                    with core.operation(): pass

if __name__=='__main__': unittest.main()
