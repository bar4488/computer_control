from loguru import logger

from connection import ComputerClientConnection
from server import LocalServer


def main():
    LocalServer(ComputerClientConnection).server_forever("0.0.0.0", 8765)

if __name__ == "__main__":
    main()
