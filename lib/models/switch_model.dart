class PortData {
  final int portId;
  final String linkedDevice;
  final int status;
  final int vlan;

  PortData({
    required this.portId,
    required this.linkedDevice,
    required this.status,
    required this.vlan,
  });

  factory PortData.fromJson(Map<String, dynamic> json) {
    return PortData(
      portId: json['portId'] ?? 0,
      linkedDevice: json['linkedDevice'] ?? "",
      status: int.tryParse(json['Status'].toString()) ?? 0,
      vlan: int.tryParse(json['Vlan'].toString()) ?? 1,
    );
  }
}

class SwitchData {
  final String name;
  final String ip;
  final String uptime;
  final List<PortData> ports;

  SwitchData({
    required this.name,
    required this.ip,
    required this.uptime,
    required this.ports,
  });

  factory SwitchData.fromJson(Map<String, dynamic> json) {
    var list = json['port'] is List ? json['port'] as List : [];
    List<PortData> portList = list.map((i) => PortData.fromJson(i)).toList();
    return SwitchData(
      name: json['name'] ?? "",
      ip: json['ip'] ?? "",
      uptime: json['uptime'] ?? "",
      ports: portList,
    );
  }
}