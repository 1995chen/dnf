package main

import (
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"log"
	"strconv"
)

func main() {
	var (
		yourText = []byte("uu5!^%jg")                 // 你的加密串（自行修改）
		key      = []byte("troqkddmtroqkcdm")         // 密钥 （勿动）
		postFix  = "e8b10c1f8bc3595be8b10c1f8bc3595b" // 补充信息（勿动）
	)

	tc, err := NewCipher(key)
	if err != nil {
		log.Fatalln(err)
	}
	dst, dst1 := make([]byte, 8), make([]byte, 8)
	tc.Encrypt(dst, yourText)
	result := hex.EncodeToString(dst) + postFix
	fmt.Println("加密后：", result)
	tc.Decrypt(dst1, dst)
	fmt.Println("解密后：", string(dst1))
}

type teaCipher struct {
	key []byte
}

type KeySizeError int

func (k KeySizeError) Error() string {
	return "tea: invalid key size " + strconv.Itoa(int(k))
}

func NewCipher(key []byte) (*teaCipher, error) {
	if len(key) != 16 {
		return nil, KeySizeError(len(key))
	}
	cipher := new(teaCipher)
	cipher.key = key
	return cipher, nil
}

func (c *teaCipher) BlockSize() int {
	return 8
}

func (c *teaCipher) Encrypt(dst, src []byte) {
	var (
		end                  = binary.BigEndian
		v0, v1               = end.Uint32(src), end.Uint32(src[4:])
		sum           uint32 = 0
		delta         uint32 = 0x9E3779B9 // 黄金分割位
		CorrectionBit uint32 = 0x7FFFFFF  // 修正位
	)
	for i := 0; i < 32; i++ {
		tv1 := (v1 << 4) ^ (v1 >> 5 & CorrectionBit)
		tv2 := unpack(c.key, (sum&3)*4)
		v0 += (tv1 + v1) ^ (tv2 + sum)
		sum += delta
		tv1 = (v0 << 4) ^ (v0 >> 5 & CorrectionBit)
		tv2 = unpack(c.key, ((sum>>11)&3)*4)
		v1 += (tv1 + v0) ^ (tv2 + sum)
	}
	end.PutUint32(dst, v0)
	end.PutUint32(dst[4:], v1)
}

func (c *teaCipher) Decrypt(dst, src []byte) {
	var (
		end                  = binary.BigEndian
		v0, v1               = end.Uint32(src[0:4]), end.Uint32(src[4:8])
		delta         uint32 = 0x9E3779B9 // 黄金分割位
		sum           uint32 = delta << 5
		CorrectionBit uint32 = 0x7FFFFFF // 修正位
	)
	for i := 0; i < 32; i++ {
		tv1 := (v0 << 4) ^ (v0 >> 5 & CorrectionBit)
		tv2 := unpack(c.key, ((sum>>11)&3)*4)
		v1 -= (tv1 + v0) ^ (tv2 + sum)
		sum -= delta
		tv1 = (v1 << 4) ^ (v1 >> 5 & CorrectionBit)
		tv2 = unpack(c.key, (sum&3)*4)
		v0 -= (tv1 + v1) ^ (tv2 + sum)
	}
	end.PutUint32(dst, v0)
	end.PutUint32(dst[4:], v1)
}

func unpack(tmp []byte, start uint32) uint32 {
	tmp = tmp[start:]
	a := tmp[3]
	b := tmp[2]
	c := tmp[1]
	d := tmp[0]
	return uint32(d) | uint32(c)<<8 | uint32(b)<<16 | uint32(a)<<24
}
