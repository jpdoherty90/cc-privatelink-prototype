from polygon import WebSocketClient
from polygon.websocket.models import WebSocketMessage
from typing import List

ws = WebSocketClient(api_key=<API_KEY>, subscriptions=["AM.*"])

def handle_msg(msg: List[WebSocketMessage]):
    for m in msg:
        print(m)

ws.run(handle_msg=handle_msg)