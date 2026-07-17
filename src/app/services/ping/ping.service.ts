import {EventEmitter, Injectable} from '@angular/core';
import {HttpClient} from "@angular/common/http";
import {catchError, interval, mergeMap, Observable, of, retry, Subscription, switchMap, timeout} from "rxjs";
import {PingResponse} from "../../datatypes/ping-response";
import {ConnectionService} from "../connection/connection.service";
import {Connection} from "../../datatypes/connection";
import {SettingsService} from "../settings/settings.service";

/** Ping 服务，定期检测 Macro Deck 服务器的可用性 */
@Injectable({
  providedIn: 'root'
})
export class PingService {
  /** 连接变为可用时触发 */
  public connectionAvailable: EventEmitter<Connection> = new EventEmitter();

  /** 连接变为不可用时触发 */
  public connectionUnavailable: EventEmitter<Connection> = new EventEmitter();

  /** 定时检测订阅 */
  private subscription: Subscription = new Subscription();

  /** 当前可用的连接 id 列表 */
  public availableConnections: string[] = [];

  /** USB 连接是否可用 */
  public usbConnectionAvailable: boolean = false;

  constructor(private http: HttpClient,
              private connectionService: ConnectionService) { }

  /**
   * 启动定期 Ping 检测
   * 对 USB 连接和所有已保存的网络连接进行可用性检测
   */
  async start() {
    this.subscription = new Subscription();

    // 检测 USB 连接可用性（1秒间隔）
    let usbConnection: Connection = await this.connectionService.getUsbConnection();

    this.subscription.add(this.periodicRequest(this.getPingUrl(usbConnection), 1000).subscribe(response => {
      if (response !== null) {
        this.addAvailableConnection(usbConnection);
      } else {
        this.removeAvailableConnection(usbConnection);
      }
    }));

    // 检测所有网络连接可用性（1.5秒间隔）
    let connections = await this.connectionService.getConnections();
    for (const connection of connections) {
      this.subscription.add(this.periodicRequest(this.getPingUrl(connection), 1500).subscribe(response => {
        if (response !== null) {
          this.addAvailableConnection(connection);
        } else {
          this.removeAvailableConnection(connection);
        }
      }));
    }
  }

  /** 停止定期 Ping 检测 */
  stop() {
    this.subscription.unsubscribe();
  }

  /** 重启 Ping 检测 */
  async restart() {
    this.stop();
    await this.start();
  }

  /**
   * 根据连接配置生成 Ping 请求地址
   * @param connection 连接配置
   * @returns Ping URL
   */
  private getPingUrl(connection: Connection) {
    // SSL 且端口为默认 8191 时换算到 8192，与 WebSocket 连接保持一致。
    const port = connection.ssl && connection.port === 8191 ? 8192 : connection.port;
    return `${connection.ssl ? "https" : "http"}://${connection.host}:${port}/ping`;
  }

  /**
   * 从可用连接列表中移除指定连接
   * @param connection 要移除的连接
   */
  private removeAvailableConnection(connection: Connection) {
    let existingConnectionIndex = this.availableConnections.findIndex(x => x == connection.id);
    if (existingConnectionIndex !== -1) {
      this.availableConnections.splice(existingConnectionIndex, 1);
      this.connectionUnavailable.emit(connection);
      if (connection.usbConnection) {
        this.usbConnectionAvailable = false;
      }
    }
  }

  /**
   * 向可用连接列表中添加指定连接
   * @param connection 要添加的连接
   */
  private addAvailableConnection(connection: Connection) {
    if (this.availableConnections.find(x => x == connection.id)) {
      return;
    }
    if (connection.usbConnection) {
      this.usbConnectionAvailable = true;
    }
    this.availableConnections.push(connection.id);
    this.connectionAvailable.emit(connection);
  }

  /**
   * 创建定时 HTTP 请求流
   * @param url 请求地址
   * @param intervalTime 请求间隔时间（毫秒）
   * @returns 定时请求的 Observable
   */
  private periodicRequest(url: string, intervalTime: number): Observable<any> {
    return interval(intervalTime).pipe(
      switchMap(() => this.http.get(url).pipe(
        timeout(800),  // 超时时间 800ms，超过即视为不可用
        catchError(error => {
          return of(null);
        })
      ))
    );
  }

}
