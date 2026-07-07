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

    // 布局标识：send-buttons 在 header 内（第二个 ion-toolbar），不再放 footer。
    // 用于确认运行时代码是否为最新版：如果日志里 layout != header-buttons-v2，说明 app 还在跑旧构建。
    console.info('[SendText] BUILD_MARK layout=header-buttons-v2 (2026-07-07)');
    console.info('[SendText] ngOnInit subscribing to ws events');
    // 连接断开时自动关闭弹窗（closed 事件覆盖主动关闭与被动断开）
    this.subscriptions.add(
      this.websocketService.closed.subscribe(() => {
        console.info('[SendText] received closed');
        this.dismissIfOpen('closed');
      })
    );
    this.subscriptions.add(
      this.websocketService.connectionLost.subscribe(() => {
        console.info('[SendText] received connectionLost');
        this.dismissIfOpen('connectionLost');
      })
    );
    this.subscriptions.add(
      this.websocketService.connectionFailed.subscribe(() => {
        console.info('[SendText] received connectionFailed');
        this.dismissIfOpen('connectionFailed');
      })
    );
  }

  ngOnDestroy() {
    console.info('[SendText] ngOnDestroy unsubscribe');
    this.subscriptions.unsubscribe();
  }

  cancel() {
    this.modalController.dismiss();
  }

  private async dismissIfOpen(reason: string) {
    try {
      const top = await this.modalController.getTop();
      console.info(`[SendText] dismissIfOpen reason=${reason} hasTop=${!!top}`);
      if (top) {
        await this.modalController.dismiss();
        console.info(`[SendText] dismissed (reason=${reason})`);
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

    // 剪贴板模式：将换行统一规范化为 Windows 风格 \r\n。
    // 原因：HTML textarea 的换行是 \n（LF），Windows 剪贴板文本约定用 \r\n（CRLF）；
    // 记事本能识别单 \n，但 cmd.exe/Windows Terminal 的粘贴处理只认 \r\n，
    // 收到 \n 会当空白吞掉，导致多行文本粘贴后被合并成一行。
    // 键盘模式保持原文，由服务端逐字符模拟按键（服务端会把 \n 视作 Enter）。
    const payload = mode === 'clipboard'
      ? this.text.replace(/\r\n/g, '\n').replace(/\n/g, '\r\n')
      : this.text;

    const lfCount = (this.text.match(/\n/g) || []).length;
    const crlfCount = (payload.match(/\r\n/g) || []).length;
    console.info(`[SendText] send mode=${mode} len=${payload.length} lfInSource=${lfCount} crlfInPayload=${crlfCount}`);

    const message = mode === 'keyboard'
      ? Protocol2Messages.getSendTextMessage(payload)
      : Protocol2Messages.getSendTextClipboardMessage(payload);
    this.websocketService.send(message);
  }
}
