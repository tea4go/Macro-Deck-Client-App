import {Component, OnInit} from '@angular/core';
import {IonicModule, ModalController} from '@ionic/angular';
import {FormsModule} from '@angular/forms';
import {TranslatePipe} from '@ngx-translate/core';
import {WebsocketService} from '../../../../services/websocket/websocket.service';
import {Protocol2Messages} from '../../../../datatypes/protocol2/protocol2-messages';

@Component({
  selector: 'app-send-text-modal',
  templateUrl: './send-text-modal.component.html',
  styleUrls: ['./send-text-modal.component.scss'],
  standalone: true,
  imports: [IonicModule, FormsModule, TranslatePipe]
})
export class SendTextModalComponent implements OnInit {
  text: string = '';

  private readonly STORAGE_KEY = 'send_text_last_input';

  constructor(
    private modalController: ModalController,
    private websocketService: WebsocketService
  ) {}

  ngOnInit() {
    const saved = localStorage.getItem(this.STORAGE_KEY);
    if (saved) this.text = saved;
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

  private send(mode: 'keyboard' | 'clipboard') {
    if (!this.text) return;
    localStorage.setItem(this.STORAGE_KEY, this.text);
    const message = mode === 'keyboard'
      ? Protocol2Messages.getSendTextMessage(this.text)
      : Protocol2Messages.getSendTextClipboardMessage(this.text);
    this.websocketService.send(message);
    this.modalController.dismiss();
  }
}
