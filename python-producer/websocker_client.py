from polygon import WebSocketClient
from polygon.websocket.models import WebSocketMessage, Market
from typing import List

# Use feed='delayed.polygon.io' because my polygon subscription only allows 15 min delayed data
# If you have premium plan you can omit that line or put feed='polygon.io'
# Subscribing to "AM.*" means all stocks, aggregated by minute
# This returns about 4,000 messages each minute, representing the 4,000 US stocks traded over that minute
ws = WebSocketClient(api_key="<API_KEY>", feed='delayed.polygon.io', market='stocks', subscriptions=["AM.*"])

def handle_msg(msg: List[WebSocketMessage]):
    for m in msg:
        print(m)

ws.run(handle_msg=handle_msg)
