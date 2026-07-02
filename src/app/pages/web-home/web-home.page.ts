import {Component, Inject, OnInit} from '@angular/core';
import {SettingsService} from "../../services/settings/settings.service";
import { DOCUMENT } from "@angular/common";
import {WebsocketService} from "../../services/websocket/websocket.service";
import {environment} from "../../../environments/environment";
import {IonicModule} from "@ionic/angular";
import {TranslatePipe} from "@ngx-translate/core";

/** Web 版首页组件，用于浏览器端直接连接同源的 Macro Deck 服务器 */
@Component({
  selector: 'app-web-home',
  templateUrl: './web-home.page.html',
  styleUrls: ['./web-home.page.scss'],
  imports: [
    IonicModule,
    TranslatePipe
]
})
export class WebHomePage implements OnInit {

  /** 客户端 ID */
  clientId: string | undefined;
  /** 应用版本号 */
  version: string | undefined;

  /** 是否处于连接丢失状态 */
  connectionLost: boolean = false;
  /** 重试倒计时秒数 */
  retryCountdown: number = 10;

  /** 倒计时定时器引用 */
  private interval: any;

  constructor(@Inject(DOCUMENT) private document: Document,
              private websocketService: WebsocketService,
              private settingsService: SettingsService) { }

  /**
   * 组件初始化回调
   * 获取客户端信息，自动连接并监听连接丢失事件
   */
  async ngOnInit() {
    this.clientId = await this.settingsService.getClientId();
    // 显示与 Android build.gradle 同步的版本（由 Sync-AppVersion 写入 environment）
    this.version = `v${environment.version}.${environment.versionCode}`;
    await this.connect();
    this.websocketService.connectionLost.subscribe(async () => {
      await this.lostConnection();
    });
  }

  /**
   * 处理连接丢失
   * 启动重试倒计时，10 秒后自动重连
   */
  async lostConnection() {
    this.connectionLost = true;
    this.retryCountdown = 10;
    this.interval = setInterval(async () => {
      this.retryCountdown--;
      if (this.retryCountdown == 0) {
        await this.connect();
      }
    }, 1000);
  }

  /**
   * 连接到 Macro Deck 服务器
   * 优先使用 URL 查询参数 ?server= 指定的地址，缺省时回退到同源服务器
   */
  async connect() {
    clearInterval(this.interval);
    this.connectionLost = false;
    const websocketUrl = this.resolveWebsocketUrl();
    await this.websocketService.connectToString(websocketUrl);
  }

  /**
   * 解析要连接的 WebSocket 地址
   * 优先读取 URL 查询参数 ?server=（便于在非同源托管时手动指定服务器），
   * 缺省时回退到「连接网页同源服务器」的默认行为
   * @returns ws/wss 开头的完整 WebSocket 地址
   */
  private resolveWebsocketUrl(): string {
    const server = new URLSearchParams(this.document.location.search).get('server');
    if (server && server.trim()) {
      return this.toWebsocketUrl(server.trim());
    }
    // 默认：连接网页同源服务器（Web 版由 Macro Deck 服务端自身托管时的场景）
    const urlParts = this.document.baseURI.split('/');
    // 将 http/https 协议替换为 ws/wss
    const wsProtocol = urlParts[0].toLowerCase().replace('http', 'ws');
    const host = urlParts[2];
    return `${wsProtocol}//${host}`;
  }

  /**
   * 把用户提供的 server 值规整为 ws/wss 地址
   * 兼容：host:port（默认 ws://）、ws(s)://host:port（原样）、http(s)://host:port（转 ws/wss）
   * @param server 用户在 ?server= 中提供的服务器地址
   * @returns ws/wss 开头的完整 WebSocket 地址
   */
  private toWebsocketUrl(server: string): string {
    const lower = server.toLowerCase();
    if (lower.startsWith('ws://') || lower.startsWith('wss://')) {
      return server;
    }
    if (lower.startsWith('https://')) {
      return 'wss://' + server.substring('https://'.length);
    }
    if (lower.startsWith('http://')) {
      return 'ws://' + server.substring('http://'.length);
    }
    // 裸 host:port，默认非加密 ws://
    return 'ws://' + server;
  }

  protected readonly environment = environment;
}
