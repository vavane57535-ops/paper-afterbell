#!/usr/bin/env python3
"""Relais UDP qui simule le ping entre un client Godot (ENet) et l'hôte, sur la même machine.

Le client se connecte au port d'écoute du relais ; le relais renvoie chaque datagramme vers l'hôte
(et les réponses vers le client) après un retard : ping / 2 dans chaque sens, plus un jitter
gaussien. L'ordre des paquets est conservé (un vrai réseau réordonne très rarement), une perte
optionnelle peut être ajoutée. À la fin, le relais écrit ses compteurs (octets et paquets par sens).

  python3 tools/net_lag_proxy.py --listen 28512 --target 28511 --ping 50 --jitter 6 \
      --duration 120 --stats /tmp/proxy.json
"""
import argparse
import asyncio
import json
import random
import signal
import time


class Direction:
	def __init__(self, name: str, one_way: float, jitter: float, loss: float):
		self.name = name
		self.one_way = one_way
		self.jitter = jitter
		self.loss = loss
		self.last_due = 0.0
		self.packets = 0
		self.bytes = 0
		self.dropped = 0
		self.sizes = []

	def due(self, loop: asyncio.AbstractEventLoop) -> float:
		delay = self.one_way + (random.gauss(0.0, self.jitter) if self.jitter > 0 else 0.0)
		delay = max(0.0, delay)
		at = max(loop.time() + delay, self.last_due + 1e-5)
		self.last_due = at
		return at

	def count(self, data: bytes) -> bool:
		if self.loss > 0 and random.random() < self.loss:
			self.dropped += 1
			return False
		self.packets += 1
		self.bytes += len(data)
		if len(self.sizes) < 200000: self.sizes.append(len(data))
		return True

	def report(self, seconds: float) -> dict:
		sizes = sorted(self.sizes)
		mean = sum(sizes) / len(sizes) if sizes else 0.0
		return {
			"packets": self.packets, "bytes": self.bytes, "dropped": self.dropped,
			"packets_per_s": round(self.packets / seconds, 2) if seconds > 0 else 0,
			"payload_bytes_per_s": round(self.bytes / seconds, 1) if seconds > 0 else 0,
			# 28 octets d'en-têtes IPv4 + UDP par datagramme : ce qui passe réellement sur la ligne.
			"wire_bytes_per_s": round((self.bytes + 28 * self.packets) / seconds, 1) if seconds > 0 else 0,
			"mean_payload": round(mean, 1),
			"p95_payload": sizes[int(len(sizes) * 0.95)] if sizes else 0,
			"max_payload": sizes[-1] if sizes else 0,
		}


class Upstream(asyncio.DatagramProtocol):
	"""Socket vers l'hôte, une par client."""

	def __init__(self, relay, client_addr):
		self.relay = relay
		self.client_addr = client_addr
		self.transport = None
		self.pending = []

	def connection_made(self, transport):
		self.transport = transport
		for data in self.pending: self.transport.sendto(data)
		self.pending.clear()

	def datagram_received(self, data, addr):
		self.relay.to_client(self.client_addr, data)

	def send(self, data):
		if self.transport is None: self.pending.append(data)
		else: self.transport.sendto(data)


class Relay(asyncio.DatagramProtocol):
	def __init__(self, loop, target, up: Direction, down: Direction):
		self.loop = loop
		self.target = target
		self.up = up
		self.down = down
		self.transport = None
		self.clients = {}

	def connection_made(self, transport):
		self.transport = transport

	def datagram_received(self, data, addr):
		if addr not in self.clients:
			upstream = Upstream(self, addr)
			self.clients[addr] = upstream
			self.loop.create_task(self.loop.create_datagram_endpoint(lambda: upstream, remote_addr=self.target))
		upstream = self.clients[addr]
		if not self.up.count(data): return
		self.loop.call_at(self.up.due(self.loop), upstream.send, data)

	def to_client(self, client_addr, data):
		if not self.down.count(data): return
		self.loop.call_at(self.down.due(self.loop), self._send_client, data, client_addr)

	def _send_client(self, data, client_addr):
		if self.transport is not None: self.transport.sendto(data, client_addr)


async def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--listen", type=int, required=True)
	parser.add_argument("--target", type=int, required=True)
	parser.add_argument("--ping", type=float, default=50.0, help="aller-retour ajouté, en ms")
	parser.add_argument("--jitter", type=float, default=0.0, help="écart type du jitter par sens, en ms")
	parser.add_argument("--loss", type=float, default=0.0, help="perte par sens, en %")
	parser.add_argument("--duration", type=float, default=300.0)
	parser.add_argument("--stats", default="")
	args = parser.parse_args()
	loop = asyncio.get_running_loop()
	one_way = args.ping / 2000.0
	up = Direction("client_to_host", one_way, args.jitter / 1000.0, args.loss / 100.0)
	down = Direction("host_to_client", one_way, args.jitter / 1000.0, args.loss / 100.0)
	relay = Relay(loop, ("127.0.0.1", args.target), up, down)
	await loop.create_datagram_endpoint(lambda: relay, local_addr=("127.0.0.1", args.listen))
	print("PROXY_READY listen=%d target=%d ping=%.0fms jitter=%.1fms loss=%.1f%%" % (args.listen, args.target, args.ping, args.jitter, args.loss), flush=True)
	started = time.monotonic()
	stop = asyncio.Event()
	for sig in (signal.SIGTERM, signal.SIGINT): loop.add_signal_handler(sig, stop.set)
	try:
		await asyncio.wait_for(stop.wait(), timeout=args.duration)
	except asyncio.TimeoutError:
		pass
	seconds = time.monotonic() - started
	report = {"ping_ms": args.ping, "jitter_ms": args.jitter, "loss_pct": args.loss, "seconds": round(seconds, 2), "up": up.report(seconds), "down": down.report(seconds)}
	if args.stats:
		with open(args.stats, "w") as handle: json.dump(report, handle, indent=2)
	print("PROXY_STATS " + json.dumps(report), flush=True)


if __name__ == "__main__":
	asyncio.run(main())
