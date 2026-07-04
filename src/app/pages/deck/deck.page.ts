import {Component} from '@angular/core';
import {WebsocketService} from "../../services/websocket/websocket.service";
import {Router} from "@angular/router";
import {SettingsModalComponent} from "../shared/modals/settings-modal/settings-modal.component";
import {SendTextModalComponent} from "./modals/send-text-modal/send-text-modal.component";
import {IonicModule, ModalController, ViewDidEnter, ViewDidLeave} from "@ionic/angular";
import {environment} from "../../../environments/environment";
import {SettingsService} from "../../services/settings/settings.service";
import {DiagnosticService} from "../../services/diagnostic/diagnostic.service";
import {NavigationService} from "../../services/navigation/navigation.service";
import {NavigationDestination} from "../../enums/navigation-destination";
import {WidgetGridComponent} from "./widget-grid/widget-grid.component";
import {TranslatePipe} from "@ngx-translate/core";


/** 控制面板页面组件，显示 Macro Deck 的按钮面板 */
@Component({
  selector: 'app-deck',
  templateUrl: './deck.page.html',
  styleUrls: ['./deck.page.scss'],
  imports: [
    IonicModule,
    WidgetGridComponent,
    TranslatePipe
]
})
export class DeckPage implements ViewDidEnter {

  /** 是否显示菜单按钮 */
  showMenuButton: boolean = true;
  /** 客户端 ID */
  clientId: string = "";
  /** 应用版本号 */
  version: string = "";

  constructor(private websocketService: WebsocketService,
              private modalController: ModalController,
              private settingsService: SettingsService,
              private diagnosticsService: DiagnosticService,
              private navigationService: NavigationService) {
  }

  /**
   * 页面进入后回调
   * 检查连接状态，未连接则导航回首页
   */
  async ionViewDidEnter() {
    if (!this.websocketService.isConnected) {
      await this.navigationService.navigateTo(NavigationDestination.Home);
    }

    this.clientId = await this.settingsService.getClientId();
    this.version = await this.diagnosticsService.getVersion();
    await this.loadSettings();
  }

  /** 关闭 WebSocket 连接，返回首页 */
  async close() {
    this.websocketService.close();
  }

  /** 打开发送文本弹窗 */
  async openTextInput() {
    const modal = await this.modalController.create({
      component: SendTextModalComponent
    });
    await modal.present();
  }

  /**
   * 打开设置弹窗
   * 设置关闭后重新加载设置
   */
  async openSettings() {
    const modal = await this.modalController.create({
      component: SettingsModalComponent
    });
    await modal.present();
    await modal.onWillDismiss();
    await this.loadSettings();
  }

  /** 进入全屏模式 */
  openFullscreen() {
    const elem = document.documentElement;
    if (elem.requestFullscreen) {
      elem.requestFullscreen().then();
    }
  }

  /** 加载设置（菜单按钮可见性） */
  private async loadSettings() {
    this.showMenuButton = await this.settingsService.getShowMenuButton();
  }

  protected readonly environment = environment;
}
