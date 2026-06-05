package main

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"fmt"
	"strings"
	"time"
)

func main() {
	nickname := "CryptoExplorer"

	fmt.Println("=== 开始 RSA + PoW 实践 ===")
	fmt.Printf("昵称: %s\n\n", nickname)

	fmt.Println("--- 步骤1: 生成 RSA 密钥对 ---")
	privateKey, publicKey, err := generateRSAKeyPair()
	if err != nil {
		fmt.Printf("生成密钥对失败: %v\n", err)
		return
	}
	fmt.Println("RSA 密钥对生成成功！")

	for _, zeros := range []int{4, 5} {
		fmt.Printf("\n=== 处理 %d 个 0 开头的哈希值 ===\n", zeros)

		fmt.Println("\n--- 步骤2: 寻找符合条件的哈希值 ---")
		data, hashStr := findHash(nickname, zeros)

		fmt.Println("\n--- 步骤3: 用私钥对数据进行签名 ---")
		signature, err := signData(privateKey, data)
		if err != nil {
			fmt.Printf("签名失败: %v\n", err)
			return
		}
		fmt.Printf("签名成功！\n签名值: %x\n", signature)

		fmt.Println("\n--- 步骤4: 用公钥验证签名 ---")
		valid, err := verifySignature(publicKey, data, signature)
		if err != nil {
			fmt.Printf("验证失败: %v\n", err)
			return
		}
		if valid {
			fmt.Println("签名验证成功！")
		} else {
			fmt.Println("签名验证失败！")
		}

		fmt.Printf("\n--- 总结 ---\n")
		fmt.Printf("数据内容: %s\n", data)
		fmt.Printf("哈希值: %s\n", hashStr)
		fmt.Printf("签名验证: %v\n", valid)
	}
}

func generateRSAKeyPair() (*rsa.PrivateKey, *rsa.PublicKey, error) {
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return nil, nil, err
	}
	return privateKey, &privateKey.PublicKey, nil
}

func findHash(nickname string, zeros int) (string, string) {
	target := strings.Repeat("0", zeros)
	nonce := 0
	startTime := time.Now()

	for {
		data := fmt.Sprintf("%s%d", nickname, nonce)
		hash := sha256.Sum256([]byte(data))
		hashStr := fmt.Sprintf("%x", hash)

		if strings.HasPrefix(hashStr, target) {
			duration := time.Since(startTime)
			fmt.Printf("找到满足条件的哈希值！\n")
			fmt.Printf("花费时间: %v\n", duration)
			fmt.Printf("Hash 内容: %s\n", data)
			fmt.Printf("Hash 值: %s\n", hashStr)
			return data, hashStr
		}

		nonce++

		if nonce%100000 == 0 {
			fmt.Printf("已尝试 %d 个 nonce...\n", nonce)
		}
	}
}

func signData(privateKey *rsa.PrivateKey, data string) ([]byte, error) {
	hashed := sha256.Sum256([]byte(data))
	signature, err := rsa.SignPKCS1v15(rand.Reader, privateKey, crypto.SHA256, hashed[:])
	if err != nil {
		return nil, err
	}
	return signature, nil
}

func verifySignature(publicKey *rsa.PublicKey, data string, signature []byte) (bool, error) {
	hashed := sha256.Sum256([]byte(data))
	err := rsa.VerifyPKCS1v15(publicKey, crypto.SHA256, hashed[:], signature)
	if err != nil {
		return false, err
	}
	return true, nil
}
