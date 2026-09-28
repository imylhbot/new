import sys
from pathlib import Path
import plistlib
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'src'))
import phone_pairing as p

class PairTests(unittest.TestCase):
    def info(self,version='18.0',udid='phone-one'):
        return {'ProductVersion':version,'UniqueDeviceID':udid}

    def test_remote_includes_actual_udid(self):
        record={'private_key':b'fake-private','public_key':b'fake-public','identifier':'host'}
        with patch.object(p.device,'get_device_info',return_value=self.info()), patch.object(p.pairing,'ensure_remote_pairing') as ensure, patch.object(p.pairing,'payload_record',return_value=record):
            payload,_=p.prepare('phone-one')
            self.assertEqual(plistlib.loads(payload)['UDID'],'phone-one')
            ensure.assert_called_once_with('phone-one','phone-one')

    def test_usb_legacy_avoids_remote(self):
        record={'HostCertificate':b'h','DeviceCertificate':b'd'}
        with patch.object(p.device,'get_device_info',return_value=self.info('16.7')), patch.object(p.pairing,'ensure_remote_pairing') as ensure, patch.object(p.pairing,'payload_record',return_value=record):
            p.prepare('phone-one'); ensure.assert_not_called()

    def test_wrong_phone_rejected(self):
        with patch.object(p.device,'get_device_info',return_value=self.info(udid='other')):
            with self.assertRaises(ValueError): p.prepare('phone-one')

    def test_remote_failure_not_silently_downgraded(self):
        with patch.object(p.device,'get_device_info',return_value=self.info()), patch.object(p.pairing,'ensure_remote_pairing',side_effect=RuntimeError('offline')), patch.object(p.pairing,'payload_record') as payload:
            with self.assertRaises(RuntimeError): p.prepare('phone-one')
            payload.assert_not_called()

    def test_exact_ios_inbox(self):
        bid='com.mjorb.soulsign.TEAM'
        body=plistlib.dumps({'UDID':'phone-one','DeviceCertificate':b'd','HostCertificate':b'h'})
        with patch.object(p,'targets',return_value={bid:{}}), patch.object(p,'prepare',return_value=(body,{})), patch.object(p.pairing,'_write_into',return_value=['/Documents/SoulSignPairing.mobiledevicepairing']) as write:
            result=p.deliver('phone-one',bid)
            write.assert_called_once_with(bid,'phone-one',{'SoulSignPairing.mobiledevicepairing':body},('/Documents',))
            self.assertIn('尚需验证',result)

    def test_write_failure_is_error(self):
        with patch.object(p,'targets',return_value={'app':{}}), patch.object(p,'prepare',return_value=(b'',{})), patch.object(p.pairing,'deliver_to_app',return_value={'placed':False,'error':'denied'}):
            with self.assertRaises(RuntimeError): p.deliver('phone-one','app')

if __name__=='__main__': unittest.main()
