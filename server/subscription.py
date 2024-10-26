from typing import Any, Callable, Coroutine


class Subscription[T]:
    def __init__(self, callback: Callable[[T, Any], Coroutine], args: Any) -> None:
        self.args = args
        self.callback = callback
    
    async def call(self, value: T):
        await self.callback(value, self.args)

    def on_close(self, callback: Callable[[], None]):
        self.close_callback = callback

    def close(self):
        if self.close_callback is not None:
            self.close_callback()
