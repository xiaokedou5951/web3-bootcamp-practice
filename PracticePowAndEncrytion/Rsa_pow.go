package main

import (
	"crypto/sha256"
	"fmt"
	"strings"
	"time"
)

func main() {
	nickname := "CryptoExplorer"

	fmt.Println("=== 开始 PoW 实践 ===")
	fmt.Printf("昵称: %s\n\n", nickname)

	fmt.Println("--- 寻找 4 个 0 开头的哈希值 ---")
	findHash(nickname, 4)

	fmt.Println("\n--- 寻找 5 个 0 开头的哈希值 ---")
	findHash(nickname, 5)
}

func findHash(nickname string, zeros int) {
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
			break
		}

		nonce++

		if nonce%100000 == 0 {
			fmt.Printf("已尝试 %d 个 nonce...\n", nonce)
		}
	}
}
