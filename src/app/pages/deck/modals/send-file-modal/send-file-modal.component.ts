import {Component, OnDestroy, OnInit} from '@angular/core';
import {IonicModule, ModalController, ToastController} from '@ionic/angular';
import {TranslatePipe, TranslateService} from '@ngx-translate/core';
import {Subscription} from 'rxjs';
import {WebsocketService} from '../../../../services/websocket/websocket.service';
import {Protocol2Service} from '../../../../services/protocol/protocol2.service';

@Component({
  selector: 'app-send-file-modal',
  templateUrl: './send-file-modal.component.html',
  styleUrls: ['./send-file-modal.component.scss'],
  standalone: true,
  imports: [IonicModule, TranslatePipe]
})
export class SendFileModalComponent implements OnInit, OnDestroy {
  /** 选中的文件名 */
  fileName: string = '';
  /** 发送进度（0~1） */
  progress: number = 0;
  /** 是否正在发送 */
  sending: boolean = false;
  /** 是否在等待服务端确认落盘 */
  waitingAck: boolean = false;

  /** 进度百分比（整数） */
  get progressPercent(): number {
    return Math.round(this.progress * 100);
  }

  private readonly subscriptions = new Subscription();

  constructor(
    private modalController: ModalController,
    private websocketService: WebsocketService,
    private protocol2Service: Protocol2Service,
    private toastController: ToastController,
    private translate: TranslateService
  ) {}

  ngOnInit() {
    // 连接断开时自动关闭本弹窗，避免停留在无效状态
    this.subscriptions.add(this.websocketService.closed.subscribe(() => this.dismissIfOpen()));
    this.subscriptions.add(this.websocketService.connectionLost.subscribe(() => this.dismissIfOpen()));
    this.subscriptions.add(this.websocketService.connectionFailed.subscribe(() => this.dismissIfOpen()));
  }

  ngOnDestroy() {
    this.subscriptions.unsubscribe();
  }

  cancel() {
    this.modalController.dismiss();
  }

  private async dismissIfOpen() {
    const top = await this.modalController.getTop();
    if (top) {
      await this.modalController.dismiss();
    }
  }

  /** 文件选择回调：读取文件并开始分块发送 */
  async onFileSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) {
      return;
    }

    this.fileName = file.name;
    this.progress = 0;
    this.waitingAck = false;
    this.sending = true;

    try {
      const success = await this.protocol2Service.sendFile(file, (sent, total, waitingAck) => {
        this.progress = total > 0 ? sent / total : 0;
        this.waitingAck = waitingAck;
      });
      await this.showToast(success ? 'sendFile.success' : 'sendFile.failed');
    } catch {
      await this.showToast('sendFile.failed');
    } finally {
      this.sending = false;
      await this.modalController.dismiss();
    }
  }

  private async showToast(key: string) {
    const toast = await this.toastController.create({
      message: this.translate.instant(key),
      duration: 2000,
      position: 'top'
    });
    await toast.present();
  }
}
