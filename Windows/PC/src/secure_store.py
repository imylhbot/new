"""Windows current-user DPAPI persistence; no plaintext fallback."""
import ctypes
import os
from pathlib import Path
from ctypes import wintypes

MAGIC = b'SOULSIGN-DPAPI-1\0'

class Blob(ctypes.Structure):
    _fields_ = [('size', wintypes.DWORD), ('data', ctypes.POINTER(ctypes.c_ubyte))]

def crypt(data, decrypt=False):
    if os.name != 'nt':
        raise OSError('SoulSign session storage requires Windows DPAPI')
    buffer = ctypes.create_string_buffer(data)
    source = Blob(len(data), ctypes.cast(buffer, ctypes.POINTER(ctypes.c_ubyte)))
    output = Blob()
    dll = ctypes.WinDLL('crypt32', use_last_error=True)
    fn = dll.CryptUnprotectData if decrypt else dll.CryptProtectData
    fn.argtypes = [ctypes.POINTER(Blob), ctypes.c_void_p, ctypes.c_void_p,
                   ctypes.c_void_p, ctypes.c_void_p, wintypes.DWORD, ctypes.POINTER(Blob)]
    fn.restype = wintypes.BOOL
    if not fn(ctypes.byref(source), None, None, None, None, 1, ctypes.byref(output)):
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        return ctypes.string_at(output.data, output.size)
    finally:
        free = ctypes.WinDLL('kernel32').LocalFree
        free.argtypes = [ctypes.c_void_p]
        free.restype = ctypes.c_void_p
        free(output.data)

class ProtectedPath(type(Path())):
    def read_text(self, encoding=None, errors=None, **kwargs):
        raw = Path(self).read_bytes()
        if not raw.startswith(MAGIC):
            raise ValueError('Unencrypted session rejected; please sign in again')
        return crypt(raw[len(MAGIC):], True).decode(encoding or 'utf-8', errors or 'strict')

    def write_text(self, data, encoding=None, errors=None, **kwargs):
        encrypted = MAGIC + crypt(data.encode(encoding or 'utf-8', errors or 'strict'))
        temporary = Path(str(self) + '.tmp')
        temporary.write_bytes(encrypted)
        os.replace(temporary, self)
        return len(data)
