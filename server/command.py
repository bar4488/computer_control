from typing import Callable, Dict, List
from server import Connection, InvalidMessageException
import re



class Command:

    def __init__(
        self,
        command_template: str | None = None,
        regexes: List[Dict] = [],
        command_creator: Callable[[Connection], str] | None = None,
        timeout: int=10,
        cwd: str | None = None,
    ) -> None:
        self.timeout=timeout
        self.regexes: List[Dict] = regexes
        if command_creator is None:
            assert command_template is not None
            self.command_creator = lambda _: command_template
        else:
            self.command_creator = command_creator

        self.compiled_regexes = [re.compile(rx["regex"]) for rx in self.regexes]
        self.cwd = cwd

    def get_command(self, args, connection: Connection) -> str:
        assert len(args) == len(self.compiled_regexes)
        assert all([type(arg) == str for arg in args])
        command_template = self.command_creator(connection)

        for arg, rx in zip(args, self.compiled_regexes):
            if not rx.fullmatch(arg):
                raise InvalidMessageException("command format is invalid!")

        return command_template.format(*args)