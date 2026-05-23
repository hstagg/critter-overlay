"""
events.py — Thread-safe event dispatch for Critter Overlay App.

Three cross-thread call sites (hotkey callback, tray callbacks, settings-save
callback) post events here. The pygame run loop drains the queue each frame
on the main thread so mutations to overlay state happen on one thread only.
"""

import queue
from enum import Enum, auto


class Event(Enum):
    TOGGLE_PAUSE = auto()
    APPLY_CONFIG = auto()   # payload: new config dict
    SPAWN_NOW    = auto()


_queue: queue.Queue = queue.Queue()


def dispatch(event: Event, payload=None) -> None:
    """Post an event from any thread. Non-blocking."""
    _queue.put_nowait((event, payload))


def drain() -> list[tuple[Event, object]]:
    """Consume and return all pending events. Call from the main thread only."""
    items = []
    while True:
        try:
            items.append(_queue.get_nowait())
        except queue.Empty:
            break
    return items
