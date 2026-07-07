import {Component, OnDestroy, OnInit} from '@angular/core';
import {IonicModule, ModalController, ToastController} from '@ionic/angular';
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
    private websocketService: WebsocketService,
    private toastController: ToastController
  ) {}

  ngOnInit() {
    const saved = localStorage.getItem(this.STORAGE_KEY);
    if (saved) this.text = saved;

    // 布局标识：send-buttons 在 header 内（第二个 ion-toolbar），不再放 footer。
    // 用 console.warn 而非 info：Android WebView 默认只把 warn/error 转发到 logcat。
    console.warn('[SendText] BUILD_MARK layout=header-buttons-v2 (2026-07-07)');
    console.warn('[SendText] ngOnInit subscribing to ws events');
    this.subscriptions.add(
      this.websocketService.closed.subscribe(() => {
        console.warn('[SendText] received closed');
        this.dismissIfOpen('closed');
      })
    );
    this.subscriptions.add(
      this.websocketService.connectionLost.subscribe(() => {
        console.warn('[SendText] received connectionLost');
        this.dismissIfOpen('connectionLost');
      })
    );
    this.subscriptions.add(
      this.websocketService.connectionFailed.subscribe(() => {
        console.warn('[SendText] received connectionFailed');
        this.dismissIfOpen('connectionFailed');
      })
    );
  }

  ngOnDestroy() {
    console.warn('[SendText] ngOnDestroy unsubscribe');
    this.subscriptions.unsubscribe();
  }

  cancel() {
    this.modalController.dismiss();
  }

  private async dismissIfOpen(reason: string) {
    try {
      const top = await this.modalController.getTop();
      console.warn(`[SendText] dismissIfOpen reason=${reason} hasTop=${!!top}`);
      if (top) {
        await this.modalController.dismiss();
        console.warn(`[SendText] dismissed (reason=${reason})`);
      }
    } catch (e) {
      console.error(`[SendText] dismissIfOpen error (reason=${reason}):`, e);
    }
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

    // 剪贴板模式：换行统一为 Windows 风格 \r\n（cmd.exe 粘贴才认）。
    // 键盘模式：换行统一为 \r（回车键标准字符）。原本发 \n：记事本对 \n 松散兼容
    // 能换行，但 cmd 收到 \n 什么都不做，因此多行文本在 cmd 里既不换行也不执行。
    // 改发 \r 后：记事本正常换行，cmd 视作 Enter 键，逐行执行。
    const normalized = this.text.replace(/\r\n/g, '\n');
    const payload = mode === 'clipboard'
      ? normalized.replace(/\n/g, '\r\n')
      : normalized.replace(/\n/g, '\r');

    const lfCount = (this.text.match(/\n/g) || []).length;
    const crlfCount = (payload.match(/\r\n/g) || []).length;
    const crOnlyCount = (payload.match(/\r/g) || []).length - crlfCount;
    const summary = `mode=${mode} len=${payload.length} lf=${lfCount} cr=${crOnlyCount} crlf=${crlfCount}`;
    console.warn(`[SendText] send ${summary}`);
    this.showDiagToast(summary);

    const message = mode === 'keyboard'
      ? Protocol2Messages.getSendTextMessage(payload)
      : Protocol2Messages.getSendTextClipboardMessage(payload);
    this.websocketService.send(message);
  }

  private async showDiagToast(summary: string) {
    const toast = await this.toastController.create({
      message: summary,
      duration: 2500,
      position: 'top',
      color: 'dark'
    });
    await toast.present();
  }
}
