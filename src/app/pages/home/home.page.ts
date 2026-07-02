import {Component, OnInit} from '@angular/core';
import {
  AlertController, IonicModule,
  ItemReorderEventDetail,
  ModalController,
  ViewDidEnter,
  ViewDidLeave,
  ViewWillEnter
} from "@ionic/angular";
import {SettingsService} from "../../services/settings/settings.service";
import {environment} from "../../../environments/environment";
import {DiagnosticService} from "../../services/diagnostic/diagnostic.service";
import {SettingsModalComponent} from "../shared/modals/settings-modal/settings-modal.component";
import {PingService} from "../../services/ping/ping.service";
import {Connection} from "../../datatypes/connection";
import {AddConnectionComponent} from "./modals/add-connection/add-connection.component";
import {ConnectionService} from "../../services/connection/connection.service";
import {WebsocketService} from "../../services/websocket/websocket.service";
import {WakelockService} from "../../services/wakelock/wakelock.service";
import {Subscription} from "rxjs";
import {ConnectionFailedComponent} from "./modals/connection-failed/connection-failed.component";
import {AppComponent} from "../../app.component";
import {QuickSetupQrCodeData} from "../../datatypes/quick-setup-qr-code-data";
import {
  QrCodeScannerUiComponent
} from "./modals/add-connection/qr-code-scanner/qr-code-scanner-ui/qr-code-scanner-ui.component";
import {TranslatePipe, TranslateService} from "@ngx-translate/core";


/** 首页组件，管理服务器连接列表、Ping 检测和连接操作 */
@Component({
  selector: 'app-home',
  templateUrl: './home.page.html',
  styleUrls: ['./home.page.scss'],
  imports: [
    IonicModule,
    QrCodeScannerUiComponent,
    TranslatePipe
  ]
})
export class HomePage implements OnInit, ViewWillEnter, ViewDidEnter, ViewDidLeave {
  /** 客户端唯一标识符 */
  clientId: string | undefined;
  /** 应用版本号 */
  version: string | undefined;
  /** 已保存的连接列表 */
  savedConnections: Connection[] = [];
  /** 当前可用的连接 id 列表 */
  availableConnections: string[] = [];
  /** 已保存连接是否已初始化加载 */
  savedConnectionsInitialized = false;
  /** USB 连接是否可用 */
  usbConnectionAvailable: boolean = false;

  /** 事件订阅集合 */
  private subscription: Subscription = new Subscription();

  constructor(private settingsService: SettingsService,
              private modalController: ModalController,
              private diagnosticsService: DiagnosticService,
              private connectionService: ConnectionService,
              private alertController: AlertController,
              private websocketService: WebsocketService,
              private wakeLockService: WakelockService,
              private pingService: PingService,
              private translate: TranslateService) {
  }

  /**
   * 页面即将进入时回调
   * 从 Ping 服务同步当前可用连接状态
   */
  ionViewWillEnter(): void {
    // 使用 map 创建新数组而非引用，避免双向绑定问题
    this.availableConnections = this.pingService.availableConnections.map(object => object);
    this.usbConnectionAvailable = this.pingService.usbConnectionAvailable;
  }

  /**
   * 页面离开后回调
   * 停止 Ping 检测并取消所有订阅
   */
  ionViewDidLeave(): void {
    this.pingService.stop();
    this.subscription.unsubscribe();
  }

  /**
   * 页面进入后回调
   * 加载连接列表，订阅 Ping 和 WebSocket 事件，启动 Ping 检测
   */
  async ionViewDidEnter() {
    this.subscription = new Subscription();
    await this.loadConnections();

    // 监听连接变为可用事件
    this.subscription.add(this.pingService.connectionAvailable.subscribe(async connection => {
      if (!this.availableConnections.includes(connection.id)) {
        this.availableConnections.push(connection.id);
        if (connection.usbConnection) {
          this.usbConnectionAvailable = true;
          // USB 连接自动连接
          if (connection.autoConnect) {
            await this.connect(connection);
          }
          return;
        }
        // 已保存的连接开启了自动连接
        let savedConnection = this.savedConnections.find(x => x.id == connection.id);
        if (savedConnection?.autoConnect === true) {
          await this.connect(savedConnection);
        }
      }
    }));

    // 监听连接变为不可用事件
    this.subscription.add(this.pingService.connectionUnavailable.subscribe(connection => {
      if (connection.usbConnection) {
        this.usbConnectionAvailable = false;
      }
      if (this.availableConnections.includes(connection.id)) {
        this.availableConnections.splice(this.availableConnections.indexOf(connection.id), 1);
      }
    }));

    // 连接关闭后重新启动 Ping 检测
    this.subscription.add(this.websocketService.closed.subscribe(async () => {
      await this.pingService.start();
    }));

    // 连接失败时显示错误弹窗
    this.subscription.add(this.websocketService.connectionFailed.subscribe(async details => {
      await this.showConnectionFailedModal(details);
    }));

    // 监听快速设置深度链接扫描事件
    this.subscription.add(AppComponent.quickSetupLinkScanned.subscribe(async data => {
      await this.openAddConnectionModal(null, data);
    }));

    await this.pingService.start();
  }

  /**
   * 从存储中加载已保存的连接列表
   */
  private async loadConnections() {
    this.savedConnections = await this.connectionService.getConnections() ?? [];
    this.savedConnectionsInitialized = true;
  }

  /**
   * 打开新增/编辑连接弹窗
   * @param existingConnection 已有连接（编辑模式），为 null 时进入新增模式
   * @param quickSetupQrCodeData 快速设置二维码数据（可选）
   */
  async openAddConnectionModal(existingConnection?: Connection | null, quickSetupQrCodeData?: QuickSetupQrCodeData | null) {
    this.pingService.stop();
    let props = {};

    if (existingConnection) {
      // 编辑模式：传入已有连接的属性
      props = {
        id: existingConnection?.id,
        name: existingConnection?.name,
        host: existingConnection?.host,
        port: existingConnection?.port ?? 8191,
        useSsl: existingConnection?.ssl ?? false,
        autoConnect: existingConnection?.autoConnect ?? false,
        index: existingConnection?.index ?? 0,
        editConnection: true
      };
    } else if (quickSetupQrCodeData) {
      // 快速设置模式：传入二维码数据
      props = {
        quickSetupQrCodeData: quickSetupQrCodeData
      };
    }

    const modal = await this.modalController.create({
      component: AddConnectionComponent,
      componentProps: props,
      cssClass: "scanner-hide"
    });
    await modal.present();

    // 弹窗关闭后，确认则保存连接
    const {data, role} = await modal.onWillDismiss();
    if (role === 'confirm') {
      await this.connectionService.addUpdateConnection(data);
    }

    await this.loadConnections();
    await this.pingService.start();
  }

  /**
   * 处理连接列表拖拽排序
   * @param event 拖拽排序事件
   */
  async handleReorder({event}: { event: CustomEvent<ItemReorderEventDetail> }) {
    this.savedConnections = event.detail.complete(this.savedConnections);
    this.updateIndexes()
    await this.connectionService.saveConnections(this.savedConnections);
  }

  /**
   * 更新连接列表的排序索引
   */
  private updateIndexes() {
    for (let i = 0; i < this.savedConnections.length; i++) {
      this.savedConnections[i].index = i;
    }
  }

  /**
   * 删除连接（带确认提示）
   * @param connection 要删除的连接
   */
  async deleteConnection(connection: Connection) {
    const alert = await this.alertController.create({
      subHeader: this.translate.instant('home.deleteConnectionConfirm', { name: connection.name }),
      buttons: [
        {
          text: this.translate.instant('common.no'),
          role: 'cancel'
        },
        {
          text: this.translate.instant('common.yes'),
          role: 'confirm',
          handler: async () => {
            await this.connectionService.deleteConnection(connection.id);
            await this.loadConnections();
          },
        }
      ],
    });

    await alert.present();
  }

  /**
   * 编辑连接，打开编辑弹窗
   * @param connection 要编辑的连接
   */
  async editConnection(connection: Connection) {
    await this.openAddConnectionModal(connection);
  }

  /**
   * 连接到指定服务器
   * @param connection 连接配置
   */
  async connect(connection: Connection) {
    await this.wakeLockService.updateWakeLock();
    await this.websocketService.connectToConnection(connection);
  }

  /**
   * 通过 USB 连接到服务器
   */
  async connectUsb() {
    let usbConnection: Connection = await this.connectionService.getUsbConnection();
    await this.connect(usbConnection);
  }

  /**
   * 组件初始化回调
   * 获取客户端 ID 和版本号
   */
  async ngOnInit() {
    this.clientId = await this.settingsService.getClientId();
    this.version = await this.diagnosticsService.getVersion();
  }

  protected readonly environment = environment;

  /**
   * 打开设置弹窗
   * 设置关闭后重启 Ping 检测以应用新配置
   */
  async openSettings() {
    const modal = await this.modalController.create({
      component: SettingsModalComponent
    });
    await modal.present();
    await modal.onWillDismiss();
    await this.pingService.restart();
  }

  /**
   * 显示连接失败错误弹窗
   * @param errorInformation 错误详情信息
   */
  private async showConnectionFailedModal(errorInformation: String) {
    const modal = await this.modalController.create({
      component: ConnectionFailedComponent,
      componentProps: {
        name: this.websocketService.getConnection()?.name,
        errorInformation: errorInformation
      }
    });
    await modal.present();
  }

  /**
   * 是否显示捐赠按钮（iOS 平台不显示）
   * @returns 是否显示
   */
  public showDonateButton() {
    //return !this.diagnosticsService.isiOS();
    return false;
  }

  /**
   * 打开捐赠页面
   */
  public openDonate() {
    window.open("https://ko-fi.com/manuelmayer", "_blank");
  }
}
