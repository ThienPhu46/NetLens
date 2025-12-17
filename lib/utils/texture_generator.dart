import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/switch_model.dart';

class TextureGenerator {
  
  static Future<Uint8List> createLabelTexture({
    required SwitchData data,
    required double arWidth,
    required double arHeight,
  }) async {
    final double aspectRatio = arHeight / arWidth;
    final int pixelWidth = 512;
    final int pixelHeight = (pixelWidth * aspectRatio).round();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final double labelRadius = 15.0;
    final Color labelBackgroundColor = const Color(0xFF4A80CC);
    final Color labelTextColor = Colors.white;
    final Rect labelRect = Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble());
    final RRect labelRRect = RRect.fromRectAndRadius(labelRect, Radius.circular(labelRadius));
    canvas.drawRRect(labelRRect, ui.Paint()..color = labelBackgroundColor);

    // Dòng 1: Name
    final ui.ParagraphBuilder pbLine1 = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: pixelHeight * 0.22, fontWeight: FontWeight.w600, height: 1.0));
    pbLine1.pushStyle(ui.TextStyle(color: labelTextColor));
    pbLine1.addText(data.name);
    final ui.Paragraph paragraphLine1 = pbLine1.build()..layout(ui.ParagraphConstraints(width: pixelWidth.toDouble()));
    canvas.drawParagraph(paragraphLine1, ui.Offset(0, pixelHeight * 0.15));

    // Dòng 2: IP
    final ui.ParagraphBuilder pbLine2 = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: pixelHeight * 0.18, fontWeight: FontWeight.w400, height: 1.0));
    pbLine2.pushStyle(ui.TextStyle(color: labelTextColor));
    pbLine2.addText(data.ip);
    final ui.Paragraph paragraphLine2 = pbLine2.build()..layout(ui.ParagraphConstraints(width: pixelWidth.toDouble()));
    canvas.drawParagraph(paragraphLine2, ui.Offset(0, pixelHeight * 0.45));

    // Dòng 3: Uptime
    final ui.ParagraphBuilder pbLine3 = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: pixelHeight * 0.14, fontWeight: FontWeight.w400, fontStyle: FontStyle.italic, height: 1.0));
    pbLine3.pushStyle(ui.TextStyle(color: Colors.white.withOpacity(0.9)));
    pbLine3.addText("Up: ${data.uptime}");
    final ui.Paragraph paragraphLine3 = pbLine3.build()..layout(ui.ParagraphConstraints(width: pixelWidth.toDouble()));
    canvas.drawParagraph(paragraphLine3, ui.Offset(0, pixelHeight * 0.70));

    final picture = recorder.endRecording();
    final img = await picture.toImage(pixelWidth, pixelHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<Uint8List> createSwitchPanelTexture({
    required SwitchData data,
    required double arWidth,
    required double arHeight,
    required bool showVlan,
    // Callback để lấy màu từ Screen truyền vào
    required Color Function(int) getVlanColor, 
  }) async {
    final int pixelWidth = 1024;
    final double aspectRatio = arHeight / arWidth;
    final int pixelHeight = (pixelWidth * aspectRatio).round();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble()), Paint()..blendMode = BlendMode.clear);
    
    final Color outerBorderColor = const Color(0xFF000080);
    final double outerBorderWidth = 3.0;
    final Color innerFillColor = Colors.white.withOpacity(0.0);
    
    final Color portColorOnline = const Color(0xFF00E676); 
    final Color portColorOffline = const Color(0xFFD32F2F); 
    
    final Color portBorderColor = const Color(0xFFADD8E6);
    final Color lightStripeColor = const Color(0xFFFFFFFF).withOpacity(0.7);
    final Color textColor = Colors.white.withOpacity(0.9);
    final Color iconColor = Colors.white.withOpacity(0.8);
    final double mainBorderRadius = 15.0;
    final Rect frameRect = Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble());
    final RRect frameRRect = RRect.fromRectAndRadius(frameRect, Radius.circular(mainBorderRadius));
    final Paint outerBorderPaint = ui.Paint()..color = outerBorderColor..style = ui.PaintingStyle.stroke..strokeWidth = outerBorderWidth;
    canvas.drawRRect(frameRRect, outerBorderPaint);
    final Rect innerFillRect = Rect.fromLTWH(frameRect.left + outerBorderWidth / 2, frameRect.top + outerBorderWidth / 2, frameRect.width - outerBorderWidth, frameRect.height - outerBorderWidth);
    final RRect innerFillRRect = RRect.fromRectAndRadius(innerFillRect, Radius.circular(mainBorderRadius - outerBorderWidth / 2));
    final innerFillPaint = ui.Paint()..color = innerFillColor;
    canvas.drawRRect(innerFillRRect, innerFillPaint);

    final int numRows = 2;
    final int numCols = 12;
    final double leftPadding = pixelWidth * 0.3;
    final double rightPadding = pixelWidth * 0.05;
    final double vPadding = pixelHeight * 0.15;
    final double portsDrawableWidth = pixelWidth - leftPadding - rightPadding;
    final double cellWidth = portsDrawableWidth / numCols;
    final double cellHeight = (pixelHeight - (vPadding * 2)) / numRows;
    final double portHeight = cellHeight * 0.7;
    final double portWidth = cellWidth * 0.8;
    int portNumber = 0;
    final double vGap = cellHeight - portHeight;

    for (int c = 0; c < numCols; c++) {
      for (int r = 0; r < numRows; r++) {
        portNumber = 1 + (c * numRows) + r;
        final double hGap = cellWidth - portWidth;
        final double x = leftPadding + (c * cellWidth) + (hGap / 2);
        final double y = vPadding + (r * cellHeight) + (vGap / 2);
        final double mainRectHeight = portHeight * 0.8;
        final double latchHeight = portHeight * 0.2;
        final double latchWidth = portWidth * 0.5;
        final double latchStartX = x + (portWidth - latchWidth) / 2;
        final double latchEndX = latchStartX + latchWidth;
        final Path portPath = Path()..moveTo(x, y + latchHeight)..lineTo(latchStartX, y + latchHeight)..lineTo(latchStartX, y)..lineTo(latchEndX, y)..lineTo(latchEndX, y + latchHeight)..lineTo(x + portWidth, y + latchHeight)..lineTo(x + portWidth, y + portHeight)..lineTo(x, y + portHeight)..lineTo(x, y + latchHeight)..close();
        final portInfo = data.ports.firstWhere((p) => p.portId == portNumber, orElse: () => PortData(portId: portNumber, linkedDevice: "", status: 0, vlan: 1));
        
        Color currentFillColor;
        if (showVlan) {
          currentFillColor = getVlanColor(portInfo.vlan);
        } else {
          currentFillColor = (portInfo.status == 1) ? portColorOnline : portColorOffline;
        }
        canvas.drawPath(portPath, ui.Paint()..color = currentFillColor);
        canvas.drawPath(portPath, ui.Paint()..color = portBorderColor..style = ui.PaintingStyle.stroke..strokeWidth = 2.5);
        final double stripeY = y + latchHeight + mainRectHeight * 0.7;
        final double stripeHeight = portHeight * 0.08;
        final double stripeStartX = x + (portWidth - (portWidth * 0.7)) / 2;
        final int numLines = 8;
        final double lineSpacing = ((portWidth * 0.7) / (numLines + 1));
        for (int i = 0; i < numLines; i++) {
          final double lx = stripeStartX + (i * lineSpacing);
          canvas.drawLine(Offset(lx, stripeY), Offset(lx, stripeY + stripeHeight), ui.Paint()..color = lightStripeColor..strokeWidth = 2.0);
        }
        final ui.ParagraphBuilder pb = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.left, fontSize: portHeight * 0.5, fontWeight: FontWeight.w300, height: 1.0));
        pb.pushStyle(ui.TextStyle(color: textColor));
        pb.addText('$portNumber');
        final ui.Paragraph paragraph = pb.build()..layout(ui.ParagraphConstraints(width: portWidth * 0.5));
        canvas.drawParagraph(paragraph, ui.Offset(x + portWidth * 0.15, y + latchHeight + (mainRectHeight * 0.3) - (paragraph.height / 2)));
        final double boltSize = portHeight * 0.30;
        final double boltX = x + portWidth * 0.60;
        final double boltY = y + latchHeight + mainRectHeight * 0.30;
        final Path boltPath = Path()..moveTo(boltX + boltSize, boltY)..lineTo(boltX + 0.3 * boltSize, boltY + 0.5 * boltSize)..lineTo(boltX, boltY + boltSize)..lineTo(boltX + 0.7 * boltSize, boltY + 0.5 * boltSize)..close();
        canvas.drawPath(boltPath, ui.Paint()..color = iconColor);
        final ui.ParagraphBuilder starPb = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: boltSize * 0.6, fontWeight: FontWeight.bold, height: 1.0));
        starPb.pushStyle(ui.TextStyle(color: iconColor));
        starPb.addText('**');
        final ui.Paragraph starParagraph = starPb.build()..layout(ui.ParagraphConstraints(width: boltSize * 2));
        canvas.drawParagraph(starParagraph, ui.Offset(boltX + boltSize * 1.1, boltY + boltSize * 0.3));
      }
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(pixelWidth, pixelHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<Uint8List> createLinesTexture({
    required SwitchData data,
    required double arWidth,
    required double arHeight,
    required double arBaseHeight,
    required bool showVlan
  }) async {
    final int pixelWidth = 1024;
    final double totalAspectRatio = arHeight / arWidth;
    final int pixelHeight = (pixelWidth * totalAspectRatio).round();
    final double panelHeightRatio = arBaseHeight / arHeight;
    final int switchGraphicPixelHeight = (pixelHeight * panelHeightRatio).round();
    final double panelTopY = (pixelHeight / 2) - (switchGraphicPixelHeight / 2);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble()), Paint()..blendMode = BlendMode.clear);
    final int numRows = 2;
    final int numCols = 12;
    final double leftPadding = pixelWidth * 0.3;
    final double rightPadding = pixelWidth * 0.05;
    final double vPadding = switchGraphicPixelHeight * 0.15;
    final double portsDrawableWidth = pixelWidth - leftPadding - rightPadding;
    final double cellWidth = portsDrawableWidth / numCols;
    final double cellHeight = (switchGraphicPixelHeight - (vPadding * 2)) / numRows;
    final double portHeight = cellHeight * 0.7;
    final double portWidth = cellWidth * 0.8;
    final double hGap = cellWidth - portWidth;
    final double vGap = cellHeight - portHeight;

    final double labelTextFontSize = 14.0;
    final double labelMaxWidth = cellWidth * 1.6;
    final double labelHeight = labelTextFontSize * 1.2;
    final double rotationAngle = math.pi / 4;
    final double lineToLabelSpacing = 3.0;
    final double lineLengthReduction = 45.0;
    final ui.FontWeight labelFontWeight = ui.FontWeight.w800;
    final ui.Color labelColor = Colors.black;
    for (int c = 0; c < numCols; c++) {
      for (int r = 0; r < numRows; r++) {
        int portNumber = 1 + (c * numRows) + r;
        final double x = leftPadding + (c * cellWidth) + (hGap / 2);
        final double y = panelTopY + vPadding + (r * cellHeight) + (vGap / 2);
        final portData = data.ports.firstWhere((p) => p.portId == portNumber, orElse: () => PortData(portId: portNumber, linkedDevice: "", status: 0, vlan: 1));
        final double lineStartX = x + (portWidth / 2);
        double lineStartY, lineEndY;
        if (r == 0) {
          lineStartY = y;
          double pivotY = lineStartY - lineLengthReduction;
          lineEndY = pivotY + lineToLabelSpacing + labelHeight / 2;
        } else {
          lineStartY = y + portHeight;
          double pivotY = lineStartY + lineLengthReduction;
          lineEndY = pivotY - lineToLabelSpacing - labelHeight / 2;
        }
        final portLinePaint = ui.Paint()..color = Colors.white.withOpacity(0.9)..style = ui.PaintingStyle.stroke..strokeWidth = 1.8;
        canvas.drawLine(Offset(lineStartX, lineStartY), Offset(lineStartX, lineEndY), portLinePaint);
        final ui.ParagraphBuilder pbLabel = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.start, fontSize: labelTextFontSize, fontWeight: labelFontWeight, height: 1.0));
        pbLabel.pushStyle(ui.TextStyle(color: labelColor));
        String labelText = showVlan ? "Vlan: ${portData.vlan}" : (portData.linkedDevice.isNotEmpty ? portData.linkedDevice : "Port $portNumber");
        pbLabel.addText(labelText);
        final ui.Paragraph pLabel = pbLabel.build()..layout(ui.ParagraphConstraints(width: labelMaxWidth));
        canvas.save();
        canvas.translate(lineStartX, lineEndY);
        if (r == 0) {
          canvas.rotate(-rotationAngle);
          canvas.drawParagraph(pLabel, ui.Offset(0, -pLabel.height));
        } else {
          canvas.rotate(rotationAngle);
          canvas.drawParagraph(pLabel, ui.Offset(0, 0));
        }
        canvas.restore();
      }
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(pixelWidth, pixelHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}