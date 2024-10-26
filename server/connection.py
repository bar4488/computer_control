import time
from typing import Any, Callable, Coroutine, Dict
from websockets.asyncio.server import ServerConnection
from check_types import assert_list_of
from command import Command
from server import Connection
from subprocess import PIPE
import asyncio


class ComputerClientConnection(Connection):
    def __init__(self, connection: ServerConnection) -> None:
        super().__init__(connection)
        self.message_handlers: Dict[str, Dict[str, Callable[[Any, str], Coroutine]]] = {
            "content": {
                "get_commands": self.get_commands,
                "run_command": self.run_command,
            },
            "stream": {},
        }

        try:
            import commands
            self.commands = commands.commands
        except ImportError:
            print("commands file not found! fallback to default commands")
            self.commands = {
                "ipconfig": Command(
                    "ipconfig",
                ),
            }

    async def get_commands(self, message, request_id):
        return [
            {"name": key, "template": cmd.command_creator(self), "regexes": cmd.regexes, "timeout": cmd.timeout}
            for key, cmd in self.commands.items()
        ]

    async def run_command(self, message, request_id):
        assert isinstance(message.get("command"), str)
        assert_list_of(message.get("args"), str)

        assert message["command"] in self.commands
        cmd = self.commands[message["command"]]
        command = cmd.get_command(message["args"], self)
        start = time.time()

        p = await asyncio.create_subprocess_shell(command, stdin=PIPE, stdout=PIPE, stderr=PIPE, cwd=cmd.cwd)
        assert p.stdout is not None
        try:
            output, error = await asyncio.wait_for(p.communicate(), cmd.timeout)
            output = output.decode("utf8")
        except TimeoutError:
            p.kill()
            output = "timeout expired!"

        end = time.time()

        return {
            "output": output,
            "time": end - start,
        }
