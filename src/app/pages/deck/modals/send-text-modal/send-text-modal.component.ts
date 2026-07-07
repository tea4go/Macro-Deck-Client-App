import {Component, OnDestroy, OnInit} from '@angular/core';
import {IonicModule, ModalController} from '@ionic/angular';
import {FormsModule} from '@angular/forms';
import {TranslatePipe} from '@ngx-translate/core';
import {Subscription} from 'rxjs';
import {WebsocketService} from '../../../../services/websocket/websocket.service';
import {Protocol2Messages} from '../../../../datatypes/protocol2/protocol2-messages';

@Component({
  selector: 'app-send-text-modal',
  templateUrl: './send-text-modal.component.html',
  styleUrls: ['./send-text-modal.component.scss'],
  standalone: true,
  imports: [IonicModule, FormsModule, TranslatePipe]
})
export class SendTextModalComponent implements OnInit, OnDestroy {
  text: string = '';

  private readonly STORAGE_KEY = 'send_text_last_input';
  private readonly subscriptions = new Subscription();

  constructor(
    private modalController: ModalController,
    private websocketService: WebsocketService
  ) {}

  ngOnInit() {
    const saved = localStorage.getItem(this.STORAGE_KEY);
    if (saved) this.text = saved;

    // 连接断开时自动关闭弹窗（closed 事件覆盖主动关闭与被动断开）
    this.subscriptions.add(
      this.websocketService.closed.subscribe(() => this.dismissIfOpen())
    );
    this.subscriptions.add(
      this.websocketService.connectionLost.subscribe(() => this.dismissIfOpen())
    );
    this.subscriptions.add(
      this.websocketService.connectionFailed.subscribe(() => this.dismissIfOpen())
    );
  }

  ngOnDestroy() {
    this.subscriptions.unsubscribe();
  }

  cancel() {
    this.modalController.dismiss();
  }

  private async dismissIfOpen() {
    const top = await this.modalController.getTop();
    if (top) { await this.modalController.dismiss(); }
  }

  sendKeyboard() {
    this.send('keyboard');
  }

  sendClipboard() {
    this.send('clipboard');
  }

  async pasteFromClipboard() {
    try {
      const text = await navigator.clipboard.readText();
      if (text) this.text = text;
    } catch {
      // 浏览器/原生环境不支持剪贴板读取时静默忽略
    }
  }

  private send(mode: 'keyboard' | 'clipboard') {
    if (!this.text) return;
    localStorage.setItem(this.STORAGE_KEY, this.text);
    const message = mode === 'keyboard'
      ? Protocol2Messages.getSendTextMessage(this.text)
      : Protocol2Messages.getSendTextClipboardMessage(this.text);
    this.websocketService.send(message);
  }
}
