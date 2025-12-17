import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/switch_model.dart';

class ApiService {
  // Hàm gọi API thực tế
  static Future<SwitchData> fetchSwitchData(String targetIp) async {
    final String apiUrl = "http://172.0.0.192:9116/snmp?module=cisco&target=$targetIp";
    final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 2));

    if (response.statusCode == 200) {
      return _parsePrometheusText(response.body, targetIp);
    } else {
      throw Exception("Failed to load data");
    }
  }

  // Hàm tạo dữ liệu giả khi lỗi (Fallback)
  static SwitchData getFallbackData(String targetIp) {
    final String fallbackJson = '''
      {
        "name": "SW Offline",
        "model": "Fallback",
        "ip": "$targetIp",
        "uptime": "Unknown",
        "port": []
      }
    ''';
    SwitchData fallback = SwitchData.fromJson(jsonDecode(fallbackJson));
    for (int i = 1; i <= 24; i++) {
      fallback.ports.add(PortData(portId: i, linkedDevice: "", status: 0, vlan: 1));
    }
    return fallback;
  }

  // Logic phân tích text (Giữ nguyên logic Regex của bạn)
  static SwitchData _parsePrometheusText(String rawText, String targetIp) {
    String switchName = "Unknown Switch";
    String switchIp = targetIp;
    String uptimeStr = "N/A";
    List<PortData> ports = [];
    
    Map<int, int> portStatusMap = {};
    Map<int, String> portAliasMap = {};
    Map<int, int> portVlanMap = {};

    List<String> lines = const LineSplitter().convert(rawText);
    
    RegExp nameRegex = RegExp(r'sysName\{sysName="([^"]+)"\}');
    RegExp statusRegex = RegExp(r'ifOperStatus\{.*ifIndex="(\d+)".*\}\s+(\d+)');
    RegExp indexRegex = RegExp(r'ifIndex="(\d+)"');
    RegExp aliasRegex = RegExp(r'ifAlias="([^"]*)"');
    RegExp uptimeRegex = RegExp(r'sysUpTime\s+([0-9\.e\+\-]+)');
    RegExp vlanRegex = RegExp(r'(?:vmVlan|vlan_id|dot1qPvid|pvid).*ifIndex="(\d+)".*\s+(\d+)');

    for (var line in lines) {
      if (line.startsWith("#")) continue;

      var nameMatch = nameRegex.firstMatch(line);
      if (nameMatch != null) switchName = nameMatch.group(1) ?? "Unknown";

      var uptimeMatch = uptimeRegex.firstMatch(line);
      if (uptimeMatch != null) {
        try {
          double rawVal = double.parse(uptimeMatch.group(1)!);
          int totalSeconds = (rawVal / 100).round();
          Duration dur = Duration(seconds: totalSeconds);
          int days = dur.inDays;
          int hours = dur.inHours % 24;
          int minutes = dur.inMinutes % 60;
          int seconds = dur.inSeconds % 60;
          uptimeStr = "${days}d ${hours}h ${minutes}m ${seconds}s";
        } catch (e) {
          uptimeStr = "Err";
        }
      }

      var statusMatch = statusRegex.firstMatch(line);
      if (statusMatch != null) {
        int index = int.parse(statusMatch.group(1)!);
        int operStatus = int.parse(statusMatch.group(2)!);
        if (index >= 1 && index <= 24) {
          portStatusMap[index] = (operStatus == 1) ? 1 : 0;
        }
      }

      if (line.contains('ifAlias=')) {
        var idxMatch = indexRegex.firstMatch(line);
        var alMatch = aliasRegex.firstMatch(line);
        if (idxMatch != null && alMatch != null) {
          int index = int.parse(idxMatch.group(1)!);
          String alias = alMatch.group(1) ?? "";
          if (index >= 1 && index <= 24 && alias.trim().isNotEmpty) {
            portAliasMap[index] = alias;
          }
        }
      }

      var vlanMatch = vlanRegex.firstMatch(line);
      if (vlanMatch != null) {
        int index = int.parse(vlanMatch.group(1)!);
        int vlanId = int.parse(vlanMatch.group(2)!);
        if (index >= 1 && index <= 24) {
          portVlanMap[index] = vlanId;
        }
      }
    }

    for (int i = 1; i <= 24; i++) {
      ports.add(PortData(
        portId: i,
        linkedDevice: portAliasMap[i] ?? "",
        status: portStatusMap[i] ?? 0,
        vlan: portVlanMap[i] ?? 1,
      ));
    }
    return SwitchData(name: switchName, ip: switchIp, uptime: uptimeStr, ports: ports);
  }
}