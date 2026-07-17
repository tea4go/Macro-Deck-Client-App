import {Component} from '@angular/core';
import {WebsocketService} from "../../services/websocket/websocket.service";
import {Connection} from "../../datatypes/connection";
import {Subscription} from "rxjs";
import {NavigationService} from "../../services/navigation/navigation.service";
import {NavigationDestination} from "../../enums/navigation-destination";
import {IonicModule, ViewDidEnter, ViewDidLeave} from "@ionic/angular";
import {TranslatePipe} from "@ngx-translate/core";

/** 连接丢失页面组件，显示重试倒计时并自动尝试重新连接 */
@Component({
  selector: 'app-connection-lost',
  templateUrl: './connection-lost.page.html',
  styleUrls: ['./connection-lost.page.scss'],
  imports: [
    IonicModule,
    TranslatePipe
  ]
})
export class ConnectionLostPage implements ViewDidEnter, ViewDidLeave {

  /** 重试倒计时秒数 */
  retryCountdown: number = 5;

  /** 递进重连间隔（秒），与 HAP 保持一致 */
  private readonly retryIntervals: number[] = [5, 10, 30, 60];

  /** 已重试次数，用于从 retryIntervals 取对应间隔 */
  private retryCount: number = 0;

  /** 当前断开连接的配置 */
  connection: Connection | undefined;

  /** 事件订阅集合 */
  private subscription: Subscription = new Subscription();

  /** 倒计时定时器引用 */
  private interval: any;

  constructor(private websocketService: WebsocketService,
              private navigationService: NavigationService) {
    this.connection = websocketService.getConnection();
  }

  /** 页面离开时取消订阅并复位重试计数（连接已恢复或用户离开） */
  ionViewDidLeave() {
    this.subscription.unsubscribe();
    this.retryCount = 0;
  }

  /**
   * 页面进入后回调
   * 监听连接失败事件并启动重试倒计时
   */
  async ionViewDidEnter() {
    this.subscription.add(this.websocketService.connectionFailed.subscribe(() => {
      // 上一次重试失败：递增计数使下一次间隔更长
      this.retryCount++;
      this.startRetry();
    }));
    await this.startRetry();
  }

  /**
   * 启动重试倒计时
   * 按已重试次数从 retryIntervals 取间隔（5/10/30/60s，封顶 60s），到 0 时自动重连
   */
  async startRetry() {
    clearInterval(this.interval);
    this.retryCountdown = this.retryIntervals[Math.min(this.retryCount, this.retryIntervals.length - 1)];
    this.interval = setInterval(async () => {
      this.retryCountdown--;
      if (this.retryCountdown == 0) {
        await this.connect();
      }
    }, 1000);
  }

  /**
   * 尝试重新连接
   * 清除定时器，如果连接配置无效则返回首页
   */
  async connect() {
    clearInterval(this.interval);
    if (this.connection == undefined) {
      await this.navigationService.navigateTo(NavigationDestination.Home);
      return;
    }
    await this.websocketService.connectToConnection(this.connection);
  }

  /** 取消重试并返回首页 */
  async cancel() {
    clearInterval(this.interval);
    await this.navigationService.navigateTo(NavigationDestination.Home);
  }
}
