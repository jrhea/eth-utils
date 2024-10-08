
import sys
import argparse
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

def aesgcm_encrypt(key, nonce, plaintext, associated_data):
    aesgcm = AESGCM(key)
    ciphertext_with_tag = aesgcm.encrypt(nonce, plaintext, associated_data)
    return ciphertext_with_tag.hex()

def aesgcm_decrypt(key, nonce, ciphertext_with_tag, associated_data):
    aesgcm = AESGCM(key)
    plaintext = aesgcm.decrypt(nonce, ciphertext_with_tag, associated_data)
    return plaintext.hex()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='AES-GCM Encryption/Decryption')
    parser.add_argument('action', choices=['encrypt', 'decrypt'], help='Action to perform')
    parser.add_argument('key', help='Encryption key (hex)')
    parser.add_argument('nonce', help='Nonce (hex)')
    parser.add_argument('text', help='Plaintext or ciphertext (hex)')
    parser.add_argument('associated_data', help='Associated data (hex)')
    args = parser.parse_args()
    key = bytes.fromhex(args.key)
    nonce = bytes.fromhex(args.nonce)
    text = bytes.fromhex(args.text)
    associated_data = bytes.fromhex(args.associated_data)

    if args.action == 'encrypt':
        print(aesgcm_encrypt(key, nonce, text, associated_data))
    else:
        print(aesgcm_decrypt(key, nonce, text, associated_data))