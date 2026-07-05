import {Component, HostListener, OnInit} from '@angular/core';
import {IonicModule, ModalController} from '@ionic/angular';
import {FormsModule} from '@angular/forms';
import {TranslatePipe} from '@ngx-translate/core';
import {WebsocketService} from '../../../../services/websocket/websocket.service';
import {Protocol2Messages} from '../../../../datatypes/protocol2/protocol2-messages';

const HEADER_H = 56;
const FOOTER_H = 60;

@Component({
  selector: 'app-send-text-modal',
  templateUrl: './send-text-modal.component.html',
  styleUrls: ['./send-text-modal.component.scss'],
  standalone: true,
  imports: [IonicModule, FormsModule, TranslatePipe]
})
export class SendTextModalComponent implements OnInit {
  text: string = '';
  textareaHeight = '200px';

  private readonly STORAGE_KEY = 'send_text_last_input';

  constructor(
    private modalController: ModalController,
    private websocketService: WebsocketService
  ) {}

  ngOnInit() {
    this.recalcHeight();
    const saved = localStorage.getItem(this.STORAGE_KEY);
    if (saved) this.text = saved;
  }

  @HostListener('window:resize')
  recalcHeight() {
    const available = window.innerHeight - HEADER_H - FOOTER_H - 16;
    this.textareaHeight = `${Math.max(available, 100)}px`;
  }

  cancel() {
    this.modalController.dismiss();
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
