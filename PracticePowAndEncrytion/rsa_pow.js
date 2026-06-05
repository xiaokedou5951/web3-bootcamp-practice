const crypto = require('crypto');

const nickname = '昵称';

async function main() {
    console.log('=== 开始 RSA + PoW 实践 ===');
    console.log(`昵称: ${nickname}\n`);

    console.log('--- 步骤1: 生成 RSA 密钥对 ---');
    const { privateKey, publicKey } = await generateRSAKeyPair();
    console.log('RSA 密钥对生成成功！');

    for (const zeros of [4, 5]) {
        console.log(`\n=== 处理 ${zeros} 个 0 开头的哈希值 ===`);
        
        console.log('\n--- 步骤2: 寻找符合条件的哈希值 ---');
        const { data, hashStr } = findHash(nickname, zeros);

        console.log('\n--- 步骤3: 用私钥对数据进行签名 ---');
        const signature = signData(privateKey, data);
        console.log('签名成功！');
        console.log(`签名值: ${signature.toString('hex')}`);

        console.log('\n--- 步骤4: 用公钥验证签名 ---');
        const valid = verifySignature(publicKey, data, signature);
        if (valid) {
            console.log('签名验证成功！');
        } else {
            console.log('签名验证失败！');
        }

        console.log('\n--- 总结 ---');
        console.log(`数据内容: ${data}`);
        console.log(`哈希值: ${hashStr}`);
        console.log(`签名验证: ${valid}`);
    }
}

function generateRSAKeyPair() {
    return new Promise((resolve, reject) => {
        crypto.generateKeyPair('rsa', {
            modulusLength: 2048,
            publicKeyEncoding: {
                type: 'spki',    // 公钥 SPKI 格式（X.509 SubjectPublicKeyInfo）
                format: 'pem'
            },
            privateKeyEncoding: {
                type: 'pkcs8',   // 私钥 PKCS#8 格式（带算法标识）
                format: 'pem'
            }
        }, (err, publicKey, privateKey) => {
            if (err) reject(err);
            else resolve({ publicKey, privateKey });
        });
    });
}

function findHash(nickname, zeros) {
    const target = '0'.repeat(zeros);
    let nonce = 0;
    const startTime = Date.now();

    while (true) {
        const data = `${nickname}${nonce}`;
        const hash = crypto.createHash('sha256').update(data).digest('hex');

        if (hash.startsWith(target)) {
            const duration = Date.now() - startTime;
            console.log('找到满足条件的哈希值！');
            console.log(`花费时间: ${duration}ms`);
            console.log(`Hash 内容: ${data}`);
            console.log(`Hash 值: ${hash}`);
            return { data, hashStr: hash };
        }

        nonce++;

        if (nonce % 100000 === 0) {
            console.log(`已尝试 ${nonce} 个 nonce...`);
        }
    }
}

function signData(privateKey, data) {
    const sign = crypto.createSign('SHA256');
    sign.update(data);
    sign.end();
    return sign.sign(privateKey);
}

function verifySignature(publicKey, data, signature) {
    const verify = crypto.createVerify('SHA256');
    verify.update(data);
    verify.end();
    return verify.verify(publicKey, signature);
}

main().catch(console.error);
