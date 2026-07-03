import {EventEmitter, Injectable} from '@angular/core';
import {ModalController} from "@ionic/angular";
import {WebSocketSubject} from "rxjs/internal/observable/dom/WebSocketSubject";
import {Protocol2Messages} from "../../datatypes/protocol2/protocol2-messages";
import {SettingsService} from "../settings/settings.service";
import {InsecureConnectionComponent} from "../../pages/home/modals/insecure-connection/insecure-connection.component";
import {ProtocolHandlerService} from "../protocol/protocol-handler.service";
import {Subject, Subscription} from "rxjs";
import {LoadingService} from "../loading/loading.service";
import {webSocket} from "rxjs/webSocket";
import {environment} from "../../../environments/environment";
import {Connection} from "../../datatypes/connection";
import {NavigationService} from "../navigation/navigation.service";
import {NavigationDestination} from "../../enums/navigation-destination";
import {TranslateService} from "@ngx-translate/core";

/** WebSocket 通信服务，管理与 Macro Deck 服务器的实时连接 */
@Injectable({
  providedIn: 'root'
})
export class WebsocketService {
  /** 当前是否已连接 */
  public isConnected: Boolean = false;

  /** 是否正在连接中 */
  private connecting: boolean = false;
  /** 是否正在主动关闭连接 */
  private closing: boolean = false;
  /** WebSocket 连接地址 */
  private url: string = "";
  /** 当前连接配置 */
  private connection: Connection | undefined;
  /** WebSocket 主题对象，用于发送和接收消息 */
  private socket: WebSocketSubject<any> | undefined;
  /** 连接关闭事件流 */
  private connectionClosed: Subject<CloseEvent> = new Subject<CloseEvent>();
  /** 连接打开事件流 */
  private connectionOpened: Subject<any> = new Subject<any>();

  /** 连接丢失事件 */
  public connectionLost: EventEmitter<any> = new EventEmitter<any>();
  /** 连接失败事件 */
  public connectionFailed: EventEmitter<any> = new EventEmitter<any>();
  /** 连接成功事件 */
  public connected: EventEmitter<any> = new EventEmitter<any>();
  /** 连接关闭事件 */
  public closed: EventEmitter<any> = new EventEmitter<any>();

  /** 消息订阅对象 */
  private subscription: Subscription = new Subscription();

  constructor(private loadingService: LoadingService,
              private modalController: ModalController,
              private settingsService: SettingsService,
              private protocolHandlerService: ProtocolHandlerService,
              private navigationService: NavigationService,
              private translate: TranslateService) {
    this.subscribeOpenClose();
  }

  /**
   * 连接到指定的 Macro Deck 服务器
   * @param connection 服务器连接配置
   */
  public async connectToConnection(connection: Connection) {
    if (this.connecting || this.isConnected) {
      return;
    }

    if (connection.usbConnection) {
      await this.loadingService.showLoading(this.translate.instant('connection.connectingViaUsb'));
    } else {
      await this.loadingService.showLoading(this.translate.instant('connection.connectingTo', { name: connection.name }));
    }
    // 根据是否启用 SSL 构建 WebSocket 地址
    this.url = `${connection.ssl ? "wss://" : "ws://"}${connection.host}:${connection.port}`;
    this.connection = connection;
    await this.connect();
  }

  /**
   * 通过连接字符串连接到 Macro Deck 服务器
   * @param connectionString WebSocket 连接地址
   */
  public async connectToString(connectionString: string) {
    this.url = connectionString;
    await this.loadingService.showLoading(this.translate.instant('connection.connectingToMacroDeck'));
    await this.connect();
  }

  /**
   * 获取当前连接配置
   * @returns 当前连接对象或 undefined
   */
  public getConnection() {
    return this.connection;
  }

  /**
   * 建立 WebSocket 连接
   * 创建 WebSocket 主题并订阅消息、错误事件
   */
  private async connect() {
    this.closing = false;

    this.socket = webSocket({
      url: this.url,
      closeObserver: this.connectionClosed,
      openObserver: this.connectionOpened
    });

    // 监听加载弹窗取消事件，关闭连接
    this.subscription.add(this.loadingService.canceled.subscribe(() => {
      this.close();
    }))

    this.subscription = this.socket.subscribe({
      next: async (message: any) => {
        // 收到消息后交由协议处理器处理
        await this.protocolHandlerService.handleMessage(message);
      },
      error: async error => {
        await this.loadingService.dismiss();
        this.closed.emit();
        this.connecting = false;
        // 处理安全错误（如 SSL 证书不受信任）
        if (error instanceof DOMException) {
          switch (error.name) {
            case "SecurityError":
              await this.showInsecureConnectionModal();
              break;
          }
        }
      }
    });
  }

  /**
   * 订阅连接打开和关闭事件
   * 连接关闭时根据状态判断是导航首页还是显示连接丢失页面
   * 连接打开时发送连接确认消息
   */
  private subscribeOpenClose() {
    this.connectionClosed.subscribe(async closeEvent => {
      console.info("Closed with code " + closeEvent.code);
      await this.loadingService.dismiss();
      this.subscription.unsubscribe();
      this.closed.emit();
      this.connecting = false;

      // 非主动关闭且非正常关闭码，按错误处理
      if (!this.closing && closeEvent.code !== 1000) {
        await this.handleError(closeEvent);
        return;
      }

      this.isConnected = false;
      await this.navigationService.navigateTo(NavigationDestination.Home);
    });

    this.connectionOpened.subscribe(async () => {
      this.connected.emit();
      this.connecting = false;
      // 更新连接计数和上次连接记录
      await this.settingsService.increaseConnectionCount();
      await this.settingsService.setLastConnection(this.connection?.id ?? "");
      this.protocolHandlerService.setWebsocketSubject(this.socket!);
      this.isConnected = true;
      await this.loadingService.showLoading(this.translate.instant('connection.waitingForAccept'));
      // 发送连接确认消息，包含客户端 ID 和认证令牌
      let clientId = await this.settingsService.getClientId();
      this.socket?.next(Protocol2Messages.getConnectedMessage(clientId, this.connection?.token));
    });
  }

  /**
   * 主动关闭 WebSocket 连接
   */
  public close() {
    console.log("Close requested");
    this.closing = true;
    this.socket?.complete();
    this.subscription.unsubscribe();
    this.connection = undefined;
  }

  /**
   * 通过 WebSocket 发送消息
   * @param payload 要发送的消息载荷
   */
  public send(payload: any) {
    this.socket?.next(payload);
  }

  /**
   * 处理连接关闭错误
   * @param closeEvent 关闭事件对象
   */
  private async handleError(closeEvent: CloseEvent) {
    // 正常关闭码，无需处理
    if (closeEvent.code == 1000) {
      return;
    }

    // Web 版本直接触发连接丢失事件
    if (environment.webVersion) {
      this.connectionLost.emit();
      return;
    }

    // 已连接状态下断开，导航到连接丢失页面
    if (this.isConnected) {
      this.isConnected = false;
      await this.navigationService.navigateTo(NavigationDestination.ConnectionLost);
      return;
    }

    // 未建立连接时失败，触发连接失败事件并传递错误详情
    let closeDetails = `Code: ${closeEvent.code}\nReason: ${closeEvent.reason}\nWas clean: ${closeEvent.wasClean}`;
    this.connectionFailed.emit(closeDetails);
  }

  /**
   * 显示不安全连接提示弹窗
   */
  private async showInsecureConnectionModal() {
    const modal = await this.modalController.create({
      component: InsecureConnectionComponent
    });
    await modal.present();
  }
}
