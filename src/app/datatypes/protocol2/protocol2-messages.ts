/** 协议2消息构建类，用于生成与 Macro Deck 服务器通信的消息对象 */
export class Protocol2Messages {
  /**
   * 构建连接成功消息
   * @param clientId 客户端唯一标识符
   * @param token 认证令牌（可选，用于安全连接）
   * @param deviceType 设备类型（如 Android / iOS / Web）
   * @returns 连接成功消息对象
   */
  public static getConnectedMessage(clientId: string, token: string | undefined, deviceType: string) {
    let obj: any = {
      "Method": "CONNECTED",
      "Client-Id": clientId,
      "API": "20",
      "Device-Type": deviceType
    }

    // 如果提供了认证令牌，则附加到消息中
    if (token !== undefined) {
      obj.Token = token;
    }

    return obj;
  }

  /**
   * 构建获取按钮列表消息
   * @returns 请求按钮数据的消息对象
   */
  public static getGetButtonsMessage() {
    return {
      "Method": "GET_BUTTONS"
    }
  }

  public static getSendTextMessage(text: string) {
    return {
      "Method": "SEND_TEXT",
      "Message": text
    }
  }

  public static getSendTextClipboardMessage(text: string) {
    return {
      "Method": "SEND_TEXT_CLIPBOARD",
      "Message": text
    }
  }

  /** 构建心跳请求消息 */
  public static getPingMessage() {
    return {
      "Method": "PING"
    }
  }

  /** 构建文件传输开始消息 */
  public static getSendFileBeginMessage(transferId: string, fileName: string, fileSize: number) {
    return {
      "Method": "SEND_FILE_BEGIN",
      "TransferId": transferId,
      "FileName": fileName,
      "FileSize": fileSize
    }
  }

  /** 构建文件传输数据块消息（data 为 base64） */
  public static getSendFileChunkMessage(transferId: string, data: string) {
    return {
      "Method": "SEND_FILE_CHUNK",
      "TransferId": transferId,
      "Data": data
    }
  }

  /** 构建文件传输结束消息 */
  public static getSendFileEndMessage(transferId: string) {
    return {
      "Method": "SEND_FILE_END",
      "TransferId": transferId
    }
  }
}
