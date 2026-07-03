#!/usr/bin/env python3
"""Stage 05 — sim/wall clock offset 측정.

MORAI가 rosbridge로 노출하는 stamped 토픽(header.stamp=sim time)을 N개 구독해
offset = wall_recv_time - header.stamp 를 평균/표준편차로 보고한다.

사용:
  source /opt/ros/humble/setup.bash
  source ~/avstack/ros2_ws/install/setup.bash
  python3 offset_probe.py --topic /Ego_topic --type EgoVehicleStatus --count 50

--type 은 morai_ros2_msgs/msg 의 클래스명(EgoVehicleStatus, GPSMessage, ObjectStatusList,
RadarDetections 등 std_msgs/Header 를 가진 타입). 또는 sensor_msgs 표준 타입도 지원.
"""
import argparse, importlib, statistics, sys
import rclpy
from rclpy.node import Node


def resolve_type(type_name: str):
    # morai_ros2_msgs 우선, 실패 시 sensor_msgs
    for pkg in ("morai_ros2_msgs.msg", "sensor_msgs.msg", "nav_msgs.msg"):
        try:
            mod = importlib.import_module(pkg)
            if hasattr(mod, type_name):
                return getattr(mod, type_name)
        except ImportError:
            continue
    raise SystemExit(f"[ERROR] 메시지 타입 '{type_name}' 를 morai_ros2_msgs/sensor_msgs 에서 찾을 수 없음")


class OffsetProbe(Node):
    def __init__(self, topic, msg_type, count):
        super().__init__("stage05_offset_probe")
        self.count = count
        self.samples = []
        self.sub = self.create_subscription(msg_type, topic, self.cb, 50)
        self.get_logger().info(f"구독 시작: {topic} (목표 {count} 샘플)")

    def cb(self, msg):
        if not hasattr(msg, "header"):
            self.get_logger().error("이 메시지 타입에 header 가 없음 — stamped 토픽을 지정하세요")
            rclpy.shutdown(); return
        stamp = msg.header.stamp.sec + msg.header.stamp.nanosec * 1e-9
        wall = self.get_clock().now().nanoseconds * 1e-9  # 시스템 wall clock (use_sim_time=off)
        if stamp <= 0.0:
            return  # 아직 sim time 미채움
        self.samples.append(wall - stamp)
        if len(self.samples) >= self.count:
            rclpy.shutdown()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--topic", required=True)
    ap.add_argument("--type", required=True, help="메시지 클래스명 (예: EgoVehicleStatus)")
    ap.add_argument("--count", type=int, default=50)
    args = ap.parse_args()

    rclpy.init()
    node = OffsetProbe(args.topic, resolve_type(args.type), args.count)
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass

    s = node.samples
    print(f"\n== sim/wall offset (wall_recv - sim_stamp), n={len(s)} ==")
    if not s:
        print("샘플 0개 — 토픽 미수신 또는 stamp 미채움. SIM publish/네트워크 설정 확인.")
        sys.exit(1)
    print(f"  mean   = {statistics.mean(s):+.6f} s")
    print(f"  median = {statistics.median(s):+.6f} s")
    if len(s) > 1:
        print(f"  stdev  = {statistics.pstdev(s):.6f} s")
    print(f"  min/max= {min(s):+.6f} / {max(s):+.6f} s")
    print("해석: mean>0 이면 sim stamp 가 wall 보다 과거(지연). stdev 는 지터 지표.")


if __name__ == "__main__":
    main()
