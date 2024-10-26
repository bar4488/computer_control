import asyncio
import traceback
from typing import Any, Coroutine, Dict, Callable, Type
from uuid import uuid4
from websockets.asyncio.server import serve, ServerConnection
import websockets.exceptions
from loguru import logger
import json

from subscription import Subscription

class InvalidMessageException(Exception):
    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class Connection:
    def __init__(self, connection: ServerConnection) -> None:
        self.my_id = str(uuid4())
        self.connection = connection
        self.subscriptions: Dict[str, Subscription] = {}
        self.request_id_to_subscription: Dict[str, str] = {}
        self.subscription_to_request_id: Dict[str, str] = {}
        self.message_handlers: Dict[str, Dict[str, Callable[[Any, str], Coroutine]]] = {
            "content": {
            },
            "stream": {

            }
        }
    
    async def handle_connection(self):
        addr = self.connection.remote_address
        logger.info(f"Got a connection from {addr}")

        try:
            async for message in self.connection:
                asyncio.create_task(self.handle_message(message, addr))
        except websockets.exceptions.ConnectionClosedError:
            logger.error(f"Connection from {addr} was terminated abruptly!")
        else:
            logger.info(f"Connection from {addr} was terminated!")

    async def handle_message(self, message, addr):
        try:
            json_message = json.loads(message)
            if "request_id" not in json_message or "content" not in json_message or "response_type" not in json_message or "message_type" not in json_message:
                logger.warning(f"Got invalid request: {json_message}! ignoring...")
                return

            request_id = json_message["request_id"]
            response_type = json_message["response_type"]
            message_type = json_message["message_type"]
            request_id = json_message["request_id"]

            content = json_message["content"]
            logger.info(f"received `{message_type}` message: {message}")
            try:
                response_content = await self._handle_message(request_id, response_type, message_type, content)
                if response_content is None:
                    response_content = {}
                await self.connection.send(json.dumps({"request_id": request_id, "content": response_content}))
            except AssertionError as e:
                error_message = "" if len(e.args) == 0 else e.args[0]
                logger.error(f"request returned an error! request: {message}, error: {e}")
                logger.debug(traceback.format_exc())
                await self.connection.send(json.dumps({"request_id": request_id, "error": error_message}))
            except InvalidMessageException as e:
                logger.error(f"request returned an error! request: {message}, error: {e.message}")
                logger.debug(traceback.format_exc())
                await self.connection.send(json.dumps({"request_id": request_id, "error": e.message}))
            
        except json.JSONDecodeError as e:
            logger.error(f"Got invalid json from {addr}: {message}, {e}, ignoring...")
        except websockets.exceptions.ConnectionClosedError:
            logger.error(f"Connection from {addr} was terminated abruptly!")

    async def _handle_message(self, request_id: str, response_type: str, message_type: str, message: Dict[str, Any]):
        if response_type == "content":
            return await self.message_handlers["content"].get(message_type, self.unknwon_message)(message, request_id)
        elif response_type == "stream":
            return await self.message_handlers["stream"].get(message_type, self.unknwon_message)(message, request_id)
        else:
            raise InvalidMessageException(f"message type {response_type} is invalid for response type {response_type}!")
    
    async def unknwon_message(self, message, request_id):
        logger.info(f"received message with unknown type `{message["type"]}`: {message}")
        return  {"error": True}
    

class LocalServer:
    def __init__(self, connection_class: Type[Connection]) -> None:
        self.connection_class = connection_class

    def error(self, request_id, message):
        return

    async def handle_connection(self, connection: ServerConnection):
        await self.connection_class(connection).handle_connection()

    async def _serve_loop(self, host, port):
        try:
            logger.info(f"starting server on {host}:{port}")
            async with serve(self.handle_connection, host, port):
                await asyncio.get_running_loop().create_future()  # run forever
        except asyncio.exceptions.CancelledError as e:
            logger.error("Interrupted! exiting...")

    def server_forever(self, host, port):
        asyncio.run(self._serve_loop(host, port))
