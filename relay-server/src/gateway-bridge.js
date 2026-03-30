/**
 * OpenClaw Gateway Bridge
 * 
 * 网桥进程：同时连接 relay-server（作为 Gateway）和 OpenClaw Gateway
 * 使用 ClawPilot 风格的 Ed25519 设备身份认证
 */

const WebSocket = require('ws');
const http = require('http');
const EventEmitter = require('events');
const { generateKeyPairSync, createPrivateKey, createPublicKey, sign, createHash } = require('crypto');
const { existsSync, mkdirSync, readFileSync, writeFileSync } = require('fs');
const { join } = require('path');
const { homedir } = require('os');

// ============================================================
// Ed25519 设备身份（ClawPilot 风格）
// ============================================================
const IDENTITY_DIR = join(homedir(), '.openclaw', 'bridge-identity');
const IDENTITY_PATH = join(IDENTITY_DIR, 'device-identity.json');
const ED25519_SPKI_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');

function base64UrlEncode(buf) {
    return buf.toString('base64').replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/g, '');
}

function rawPublicKeyBytes(publicKeyPem) {
    const key = createPublicKey(publicKeyPem);
    const spki = key.export({ type: 'spki', format: 'der' });
    if (spki.length === ED25519_SPKI_PREFIX.length + 32 &&
        spki.subarray(0, ED25519_SPKI_PREFIX.length).equals(ED25519_SPKI_PREFIX)) {
        return spki.subarray(ED25519_SPKI_PREFIX.length);
    }
    return spki;
}

function loadOrCreateDeviceIdentity() {
    if (existsSync(IDENTITY_PATH)) {
        try {
            const stored = JSON.parse(readFileSync(IDENTITY_PATH, 'utf8'));
            if (stored.deviceId && stored.publicKeyPem && stored.privateKeyPem) {
                return { deviceId: stored.deviceId, publicKeyPem: stored.publicKeyPem, privateKeyPem: stored.privateKeyPem };
            }
        } catch {}
    }
    
    const { publicKey, privateKey } = generateKeyPairSync('ed25519');
    const publicKeyPem = publicKey.export({ type: 'spki', format: 'pem' }).toString();
    const privateKeyPem = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
    const deviceId = createHash('sha256').update(rawPublicKeyBytes(publicKeyPem)).digest('hex');
    
    mkdirSync(IDENTITY_DIR, { recursive: true });
    writeFileSync(IDENTITY_PATH, JSON.stringify({ version: 1, deviceId, publicKeyPem, privateKeyPem, createdAtMs: Date.now() }, null, 2) + '\n', { mode: 0o600 });
    
    return { deviceId, publicKeyPem, privateKeyPem };
}

function buildSignedDevice(identity, opts) {
    const payload = [
        'v2',
        identity.deviceId,
        opts.clientId,
        opts.clientMode,
        opts.role,
        opts.scopes.join(','),
        String(opts.signedAtMs),
        opts.token || '',
        opts.nonce || '',
    ].join('|');
    
    const key = createPrivateKey(identity.privateKeyPem);
    const signature = base64UrlEncode(sign(null, Buffer.from(payload, 'utf8'), key));
    
    return {
        id: identity.deviceId,
        publicKey: base64UrlEncode(rawPublicKeyBytes(identity.publicKeyPem)),
        signature,
        signedAt: opts.signedAtMs,
        nonce: opts.nonce,
    };
}

// ============================================================
// 配置
// ============================================================
const args = process.argv.slice(2);
let relayWsUrl = 'ws://150.158.119.114:3001';
let gatewayPublicUrl = null;
let gatewayToken = null;
let gatewayId = null;

for (let i = 0; i < args.length; i++) {
    if (args[i] === '--relay' && args[i + 1]) relayWsUrl = args[++i];
    if (args[i] === '--url' && args[i + 1]) gatewayPublicUrl = args[++i];
    if (args[i] === '--token' && args[i + 1]) gatewayToken = args[++i];
    if (args[i] === '--gateway-id' && args[i + 1]) gatewayId = args[++i];
}

if (!gatewayPublicUrl) {
    console.error('Usage: node gateway-bridge.js --relay ws://relay:port --url wss://gateway-url --token TOKEN --gateway-id ID');
    process.exit(1);
}

const gatewayWsUrl = gatewayPublicUrl.replace(/^https:/, 'wss:').replace(/^http:/, 'ws:');
gatewayId = gatewayId || `gateway-bridge-${Date.now()}`;

// ============================================================
// 日志
// ============================================================
function log(type, msg) {
    const time = new Date().toISOString().split('T')[1].slice(0, 8);
    console.log(`[${time}] [${type}] ${msg}`);
}

function uuid() {
    return require('crypto').randomUUID();
}

// ============================================================
// Gateway Bridge
// ============================================================
class GatewayBridge extends EventEmitter {
    constructor(opts) {
        super();
        this.relayWsUrl = opts.relayWsUrl;
        this.gatewayWsUrl = opts.gatewayWsUrl;
        this.gatewayToken = opts.gatewayToken;
        this.gatewayId = opts.gatewayId;

        this.relayWs = null;
        this.gatewayWs = null;
        this.connectedToRelay = false;
        this.connectedToGateway = false;
        this.connectNonce = null;
        this.connectSent = false;
        this.pendingRequests = new Map();
        this.reconnectDelay = 1000;
        this.maxReconnectDelay = 30000;
        this.stopped = false;

        // 存储 deviceToken（ClawPilot 风格）
        this.storedDeviceToken = null;
        this.connectTimer = null;
        this.tickTimer = null;
        this.lastTick = 0;
        this.tickIntervalMs = 30_000;

        // 加载或创建设备身份
        this.identity = loadOrCreateDeviceIdentity();
        log('BRIDGE', `Device ID: ${this.identity.deviceId.substring(0, 16)}...`);
    }
    
    async start() {
        log('BRIDGE', `Starting gateway bridge...`);
        log('BRIDGE', `  -> Relay:   ${this.relayWsUrl}`);
        log('BRIDGE', `  -> Gateway: ${this.gatewayWsUrl}`);
        log('BRIDGE', `  -> ID:      ${this.gatewayId}`);
        
        try {
            await this.connectToRelay();
            log('BRIDGE', `Relay connected, connecting to Gateway...`);
            await this.connectToGateway();
            this.startKeepalive();
            log('BRIDGE', 'Gateway bridge is running!');
        } catch (err) {
            log('BRIDGE', `Failed to start: ${err.message}`);
            process.exit(1);
        }
    }
    
    stop() {
        this.stopped = true;
        log('BRIDGE', 'Stopping bridge...');
        this.relayWs?.close();
        this.gatewayWs?.close();
        process.exit(0);
    }
    
    // ----------------------------------------
    // 连接 Relay Server
    // ----------------------------------------
    async connectToRelay() {
        return new Promise((resolve, reject) => {
            log('RELAY', `Connecting to relay server...`);
            this.relayWs = new WebSocket(this.relayWsUrl);
            
            const timeout = setTimeout(() => reject(new Error('Relay connection timeout')), 15000);
            
            this.relayWs.on('open', () => {
                clearTimeout(timeout);
                log('RELAY', 'Connected to relay server, registering as gateway...');
                this.sendToRelay({ type: 'gateway', gatewayId: this.gatewayId, gatewayUrl: this.gatewayWsUrl });
            });
            
            this.relayWs.on('message', (data) => {
                try {
                    const msg = JSON.parse(data.toString());
                    this.handleRelayMessage(msg);
                    if (msg.type === 'registered' && msg.role === 'gateway') resolve();
                } catch (e) {
                    log('RELAY', `Parse error: ${e.message}`);
                }
            });
            
            this.relayWs.on('close', (code) => {
                log('RELAY', `Relay disconnected (code=${code})`);
                this.connectedToRelay = false;
                if (!this.stopped) this.scheduleRelayReconnect();
            });
            
            this.relayWs.on('error', (err) => {
                log('RELAY', `Error: ${err.message}`);
                clearTimeout(timeout);
                if (!this.connectedToRelay) reject(err);
            });
        });
    }
    
    scheduleRelayReconnect() {
        const delay = this.reconnectDelay;
        this.reconnectDelay = Math.min(this.reconnectDelay * 1.5, this.maxReconnectDelay);
        log('RELAY', `Reconnecting in ${Math.round(delay / 1000)}s...`);
        setTimeout(() => { if (!this.stopped) this.connectToRelay(); }, delay);
    }
    
    sendToRelay(msg) {
        if (this.relayWs?.readyState === WebSocket.OPEN) {
            this.relayWs.send(JSON.stringify(msg));
        }
    }
    
    // ----------------------------------------
    // 连接 OpenClaw Gateway（使用 Ed25519 设备身份，ClawPilot 风格）
    // ----------------------------------------
    async connectToGateway() {
        return new Promise((resolve, reject) => {
            log('GATEWAY', `Connecting to OpenClaw Gateway...`);

            const headers = {};
            if (this.gatewayToken) {
                headers['Authorization'] = `Bearer ${this.gatewayToken}`;
            }

            this.gatewayWs = new WebSocket(this.gatewayWsUrl, { headers });

            const timeout = setTimeout(() => {
                if (!this.connectedToGateway) {
                    this.gatewayWs.close();
                    reject(new Error('Gateway connection timeout'));
                }
            }, 20000);

            this.gatewayWs.on('open', () => {
                log('GATEWAY', 'WebSocket opened, waiting for challenge...');
                this.connectNonce = null;
                this.connectSent = false;
                // ClawPilot 风格：1秒后如果没收到 challenge 也发送 connect
                this.connectTimer = setTimeout(() => this.sendGatewayConnect(), 1000);
            });

            this.gatewayWs.on('message', (data) => {
                try {
                    const msg = JSON.parse(data.toString());
                    this.handleGatewayMessage(msg, { resolve, timeout });
                } catch (e) {
                    log('GATEWAY', `Parse error: ${e.message}`);
                }
            });

            this.gatewayWs.on('close', (code, reason) => {
                log('GATEWAY', `Gateway disconnected (code=${code})`);
                this.teardown();
                this.connectedToGateway = false;
                if (!this.stopped) this.scheduleGatewayReconnect();
            });

            this.gatewayWs.on('error', (err) => {
                clearTimeout(timeout);
                this.teardown();
                log('GATEWAY', `Error: ${err.message}`);
                if (!this.connectedToGateway) reject(err);
            });
        });
    }

    teardown() {
        if (this.connectTimer) {
            clearTimeout(this.connectTimer);
            this.connectTimer = null;
        }
        if (this.tickTimer) {
            clearInterval(this.tickTimer);
            this.tickTimer = null;
        }
    }

    scheduleGatewayReconnect() {
        if (this.stopped) return;
        const delay = this.reconnectDelay;
        this.reconnectDelay = Math.min(this.reconnectDelay * 2, 30000);
        log('GATEWAY', `Reconnecting in ${Math.round(delay / 1000)}s...`);
        setTimeout(() => { if (!this.stopped) this.connectToGateway(); }, delay).unref();
    }
    
    sendToGateway(msg) {
        if (this.gatewayWs?.readyState === WebSocket.OPEN) {
            this.gatewayWs.send(JSON.stringify(msg));
        }
    }
    
    // ----------------------------------------
    // 处理来自 Relay 的消息（App → Gateway）
    // ----------------------------------------
    handleRelayMessage(msg) {
        log('RELAY', `Received relay message type=${msg.type}, from=${msg.from}`);
        switch (msg.type) {
            case 'registered':
                if (msg.role === 'gateway') {
                    this.connectedToRelay = true;
                    this.reconnectDelay = 1000;
                    log('RELAY', `Registered as gateway: ${msg.gatewayId}`);
                }
                break;
            case 'message':
                log('RELAY', `Message content: ${JSON.stringify(msg).substring(0, 200)}`);
                if (msg.from === 'device' && msg.content) {
                    log('RELAY', `Forwarding to Gateway: ${msg.content.substring(0, 100)}`);
                    this.forwardToGateway(msg.content);
                }
                break;
            default:
                log('RELAY', `Unknown message type: ${msg.type}`);
                break;
        }
    }
    
    // ----------------------------------------
    // 处理来自 Gateway 的消息
    // ----------------------------------------
    handleGatewayMessage(msg, extra) {
        const { resolve, timeout } = extra || {};
        
        if (msg.type === 'event' && msg.event === 'connect.challenge') {
            clearTimeout(timeout);
            if (this.connectTimer) {
                clearTimeout(this.connectTimer);
                this.connectTimer = null;
            }
            this.connectNonce = msg.payload?.nonce;
            log('GATEWAY', `Got challenge nonce: ${this.connectNonce}`);
            this.sendGatewayConnect();
            if (resolve) resolve();
            return;
        }

        if (msg.type === 'res' && msg.id && this.pendingRequests.has(msg.id)) {
            clearTimeout(timeout);
            const pending = this.pendingRequests.get(msg.id);
            this.pendingRequests.delete(msg.id);
            pending(msg);
            return;
        }

        if (msg.type === 'event') {
            log('GATEWAY', `Gateway event: ${msg.event}`);
            // 处理 tick 事件
            if (msg.event === 'tick') {
                this.lastTick = Date.now();
                return;
            }
            // 转发事件到 relay
            this.forwardToRelay({ type: 'message', from: 'gateway', content: msg });
            return;
        }

        // 其他响应直接转发
        if (msg.type === 'res') {
            this.forwardToRelay({ type: 'message', from: 'gateway', content: msg });
        }
    }
    
    sendGatewayConnect() {
        if (this.connectSent) { log('GATEWAY', 'Connect already sent'); return; }
        this.connectSent = true;

        const role = 'operator';
        const scopes = ['operator.admin', 'operator.read', 'operator.write', 'operator.approvals', 'operator.pairing'];
        const clientId = 'openclaw-macos';
        const clientMode = 'ui';
        const signedAtMs = Date.now();
        const nonce = this.connectNonce ?? undefined;
        // ClawPilot 风格：优先用 storedDeviceToken
        const authToken = this.storedDeviceToken ?? this.gatewayToken;

        const signedDevice = buildSignedDevice(this.identity, {
            clientId, clientMode, role, scopes, signedAtMs,
            token: authToken ?? undefined,
            nonce,
        });

        const params = {
            minProtocol: 3,
            maxProtocol: 3,
            role,
            scopes,
            caps: ['tool-events'],
            client: {
                id: 'openclaw-macos',
                displayName: 'Macmini',
                version: '1.0.0',
                platform: process.platform,
                mode: clientMode,
            },
            device: signedDevice,
            auth: (authToken || this.gatewayToken)
                ? { token: authToken, password: this.gatewayToken }
                : undefined,
        };

        const req = { type: 'req', id: uuid(), method: 'connect', params };

        log('GATEWAY', `Sending connect request...`);
        this.sendToGateway(req);

        const reqId = req.id;
        const timeout = setTimeout(() => {
            if (this.pendingRequests.has(reqId)) {
                this.pendingRequests.delete(reqId);
                log('GATEWAY', 'Connect request timeout');
                this.connectSent = false; // allow retry
            }
        }, 15000);

        this.pendingRequests.set(reqId, (res) => {
            clearTimeout(timeout);
            if (res.ok) {
                // ClawPilot 风格：保存 deviceToken
                const deviceToken = res.payload?.auth?.deviceToken;
                if (typeof deviceToken === 'string') {
                    this.storedDeviceToken = deviceToken;
                    log('GATEWAY', `Stored deviceToken: ${deviceToken.substring(0, 8)}...`);
                }
                if (typeof res.payload?.policy?.tickIntervalMs === 'number') {
                    this.tickIntervalMs = res.payload.policy.tickIntervalMs;
                }
                this.backoffMs = 1000;
                this.lastTick = Date.now();
                this.startTickWatch();
                this.connectedToGateway = true;
                this.reconnectDelay = 1000;
                log('GATEWAY', `✅ Connected to Gateway! (role=${res.payload?.auth?.role || 'unknown'})`);
            } else {
                log('GATEWAY', `❌ Connect failed: ${JSON.stringify(res.error)}`);
                // ClawPilot 风格：清除 deviceToken，下次用原始 token 重试
                this.storedDeviceToken = null;
                this.connectSent = false; // allow retry
            }
        });
    }

    startTickWatch() {
        if (this.tickTimer) clearInterval(this.tickTimer);
        const interval = Math.max(this.tickIntervalMs, 1000);
        this.tickTimer = setInterval(() => {
            if (this.stopped || !this.lastTick) return;
            if (Date.now() - this.lastTick > this.tickIntervalMs * 2) {
                this.gatewayWs?.close(4000, 'tick timeout');
            }
        }, interval);
    }
    
    // ----------------------------------------
    // 消息转发
    // ----------------------------------------
    forwardToGateway(content) {
        if (!this.connectedToGateway) {
            log('GATEWAY', 'Gateway not connected, waiting...');
            let waitCount = 0;
            const check = () => {
                if (this.connectedToGateway) this._doForward(content);
                else if (waitCount++ < 50) setTimeout(check, 100);
                else log('GATEWAY', 'Gateway timeout, dropping message');
            };
            check();
            return;
        }
        this._doForward(content);
    }
    
    _doForward(content) {
        let msg = typeof content === 'string' ? JSON.parse(content) : content;
        if (msg.content) msg = typeof msg.content === 'string' ? JSON.parse(msg.content) : msg.content;
        
        if (msg.type === 'req') {
            const newId = uuid();
            const originalId = msg.id;
            
            const timeout = setTimeout(() => {
                if (this.pendingRequests.has(newId)) {
                    this.pendingRequests.delete(newId);
                    this.forwardToRelay({
                        type: 'message', from: 'gateway',
                        content: { type: 'res', id: originalId, ok: false, error: { code: 'TIMEOUT', message: 'Gateway request timeout' } }
                    });
                }
            }, 30000);
            
            this.pendingRequests.set(newId, (res) => {
                clearTimeout(timeout);
                this.forwardToRelay({ type: 'message', from: 'gateway', content: { ...res, id: originalId } });
                // Also notify relay HTTP proxy (if set)
                if (this.onHttpProxyResponse) {
                    this.onHttpProxyResponse(originalId, res, this.relayWs);
                }
            });
            
            msg.id = newId;
        }
        
        this.sendToGateway(msg);
    }
    
    forwardToRelay(wrapper) {
        if (!this.connectedToRelay) return;
        this.sendToRelay({
            type: 'message',
            from: 'gateway',
            content: typeof wrapper.content === 'object' ? JSON.stringify(wrapper.content) : wrapper.content,
        });
    }
    
    startKeepalive() {
        setInterval(() => {
            if (this.relayWs?.readyState === WebSocket.OPEN) this.relayWs.ping();
        }, 30000);
    }
}

// ============================================================
// 主程序
// ============================================================
const bridge = new GatewayBridge({
    relayWsUrl,
    gatewayWsUrl,
    gatewayToken,
    gatewayId,
});

process.on('SIGINT', () => bridge.stop());
process.on('SIGTERM', () => bridge.stop());

bridge.start();
