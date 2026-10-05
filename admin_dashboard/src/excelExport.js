import ExcelJS from 'exceljs';
import { saveAs } from 'file-saver';

// Helper to fetch image as base64
const fetchImageAsBase64 = async (url) => {
  const response = await fetch(url);
  const blob = await response.blob();
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result);
    reader.readAsDataURL(blob);
  });
};

export const exportStyledExcel = async (reportType, hostelFilter, todayStr, data, totals) => {
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet('Report');

  // Column widths
  if (reportType === 'individual') {
    ws.columns = [
      { width: 35 }, { width: 20 }, { width: 20 }, { width: 10 },
      { width: 10 }, { width: 10 }, { width: 15 }, { width: 12 },
      { width: 10 }, { width: 25 }
    ];
  } else {
    ws.columns = [
      { width: 30 }, { width: 15 }, { width: 10 }, { width: 15 },
      { width: 15 }, { width: 10 }, { width: 15 }, { width: 15 },
      { width: 10 }, { width: 15 }
    ];
  }

  // Add header image (fetch local public image)
  try {
    const base64Image = await fetchImageAsBase64('/kare_header.jpg');
    const imageId = wb.addImage({
      base64: base64Image,
      extension: 'jpeg',
    });
    // Add image over A1:J3
    ws.addImage(imageId, {
      tl: { col: 0, row: 0 },
      br: { col: 10, row: 4 }
    });
    // Make room for image
    ws.getRow(1).height = 30;
    ws.getRow(2).height = 30;
    ws.getRow(3).height = 30;
    ws.getRow(4).height = 30;
  } catch (e) {
    console.error('Could not load image for Excel', e);
  }

  let currentRow = 5;

  const applyCellStyles = (cell, bg, fontColor, bold, align = 'center', wrap = true) => {
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: bg } };
    cell.font = { color: { argb: fontColor }, bold, name: 'Calibri', size: 11 };
    cell.alignment = { horizontal: align, vertical: 'middle', wrapText: wrap };
    cell.border = {
      top: { style: 'thin', color: { argb: 'FF000000' } },
      left: { style: 'thin', color: { argb: 'FF000000' } },
      bottom: { style: 'thin', color: { argb: 'FF000000' } },
      right: { style: 'thin', color: { argb: 'FF000000' } }
    };
  };

  if (reportType === 'individual') {
    // Title
    ws.mergeCells(`A${currentRow}:J${currentRow}`);
    const titleCell = ws.getCell(`A${currentRow}`);
    titleCell.value = hostelFilter.toUpperCase();
    applyCellStyles(titleCell, 'FFFFE0', 'FF00008B', true); // Yellow bg, Dark Blue text
    ws.getRow(currentRow).height = 25;
    currentRow++;

    // Date
    ws.mergeCells(`A${currentRow}:J${currentRow}`);
    const dateCell = ws.getCell(`A${currentRow}`);
    dateCell.value = todayStr.split('-').reverse().join('.');
    applyCellStyles(dateCell, 'FFFFE4B5', 'FFFF0000', true); // Moccasin bg, Red text
    ws.getRow(currentRow).height = 20;
    currentRow++;

    // Headers
    const headers = [
      "NAME OF THE CT AND AW", "ROOM NUMBER", "TOTAL STUDENT STRENGTH", 
      "LEAVE", "SUSPEND", "LONG LEAVE", "ABSENT W/O PERMISSION", 
      "LEAVE EXPERID", "HOSPITAL", "STUDENT PRESENT IN HOSTEL"
    ];
    const headerRow = ws.getRow(currentRow);
    headerRow.height = 70;
    headers.forEach((h, i) => {
      const cell = headerRow.getCell(i + 1);
      cell.value = h;
      applyCellStyles(cell, 'FFD3EBF2', 'FF00008B', true); // Light Blue bg, Dark blue text
      
      // Rotate specific columns
      if (i >= 3 && i <= 8) {
        cell.alignment = { textRotation: 90, horizontal: 'center', vertical: 'middle' };
        if (i === 3 || i === 6) cell.font.color = { argb: 'FFFF0000' }; // Red text
        if (i === 4 || i === 5 || i === 7 || i === 8) cell.font.color = { argb: 'FFA52A2A' }; // Brown text
      }
    });
    currentRow++;

    // Data rows
    data.rows.forEach((r, idx) => {
      const row = ws.getRow(currentRow);
      const bg = idx % 2 === 0 ? 'FFFFF8DC' : 'FFE6F2FF'; // Alternating yellow/blue
      
      row.getCell(1).value = r.wardenName.toUpperCase();
      applyCellStyles(row.getCell(1), bg, 'FF00008B', true, 'left');
      
      row.getCell(2).value = r.roomDisplay;
      applyCellStyles(row.getCell(2), bg, 'FF00008B', true);
      
      row.getCell(3).value = r.totalStrength;
      applyCellStyles(row.getCell(3), bg, 'FF00008B', true);
      
      row.getCell(4).value = r.leave || '';
      applyCellStyles(row.getCell(4), bg, 'FFFF0000', true);
      
      row.getCell(5).value = r.suspend || '';
      applyCellStyles(row.getCell(5), bg, 'FFA52A2A', true);
      
      row.getCell(6).value = r.longLeave || '';
      applyCellStyles(row.getCell(6), bg, 'FFA52A2A', true);
      
      row.getCell(7).value = r.absentWoPermission || '';
      applyCellStyles(row.getCell(7), bg, 'FFFF0000', true);
      
      row.getCell(8).value = r.leaveExpired || '';
      applyCellStyles(row.getCell(8), bg, 'FFA52A2A', true);
      
      row.getCell(9).value = r.hospital || '';
      applyCellStyles(row.getCell(9), bg, 'FFA52A2A', true);
      
      row.getCell(10).value = r.present || '';
      applyCellStyles(row.getCell(10), bg, 'FF00008B', true);
      
      currentRow++;
    });

    // Total Row
    const tRow = ws.getRow(currentRow);
    ws.mergeCells(`A${currentRow}:B${currentRow}`);
    tRow.getCell(1).value = "TOTAL";
    applyCellStyles(tRow.getCell(1), 'FF00BFFF', 'FF00008B', true, 'right');
    applyCellStyles(tRow.getCell(2), 'FF00BFFF', 'FF00008B', true);
    
    tRow.getCell(3).value = totals.totalStrengthSum;
    applyCellStyles(tRow.getCell(3), 'FF00BFFF', 'FF000000', true);
    
    tRow.getCell(4).value = totals.leaveSum || '';
    applyCellStyles(tRow.getCell(4), 'FF00BFFF', 'FF000000', true);
    
    [5, 6].forEach(i => { tRow.getCell(i).value = ''; applyCellStyles(tRow.getCell(i), 'FF00BFFF', 'FF000000', true); });
    
    tRow.getCell(7).value = totals.absentSum || '';
    applyCellStyles(tRow.getCell(7), 'FF00BFFF', 'FF000000', true);
    
    [8, 9].forEach(i => { tRow.getCell(i).value = ''; applyCellStyles(tRow.getCell(i), 'FF00BFFF', 'FF000000', true); });
    
    tRow.getCell(10).value = totals.presentSum || '';
    applyCellStyles(tRow.getCell(10), 'FF00BFFF', 'FF000000', true);

  } else {
    // CONSOLIDATED REPORT
    ws.mergeCells(`A${currentRow}:J${currentRow}`);
    const titleCell = ws.getCell(`A${currentRow}`);
    titleCell.value = "KARE - ALL HOSTEL REPORT";
    applyCellStyles(titleCell, 'FFE6E6FA', 'FF000000', true); // Light purple
    ws.getRow(currentRow).height = 25;
    currentRow++;

    ws.mergeCells(`A${currentRow}:J${currentRow}`);
    const dateCell = ws.getCell(`A${currentRow}`);
    dateCell.value = `DAILY ATTENDANCE FOR STUDENTS DT :- ${todayStr.split('-').reverse().join(' ')}`;
    applyCellStyles(dateCell, 'FFD3EBF2', 'FF00008B', true); // Light Blue
    ws.getRow(currentRow).height = 25;
    currentRow++;

    // Headers
    const headers = [
      "NAME OF THE HOSTELS", "PRESENTLY AVALIBLE\nSTRENGTH", "ON LEAVE", 
      "ABSENT W/O\nPERMISSION", "LONG ABSENT", "HOSPITAL", "SUSPENDED", 
      "LEAVE EXPIRED", "TOTAL\nOFF", "STUDENT\nPRESENT\nIN HOSTEL"
    ];
    const headerRow = ws.getRow(currentRow);
    headerRow.height = 70;
    headers.forEach((h, i) => {
      const cell = headerRow.getCell(i + 1);
      cell.value = h;
      applyCellStyles(cell, 'FFFFFFFF', 'FF00008B', true);
      if (i >= 2 && i <= 7) {
        cell.alignment = { textRotation: 90, horizontal: 'center', vertical: 'middle' };
      }
      if (i === 7) {
        cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFC71585' } }; // Pink
        cell.font.color = { argb: 'FFFFFF00' }; // Yellow
      }
    });
    currentRow++;

    const addRow = (hData) => {
      const row = ws.getRow(currentRow);
      row.getCell(1).value = hData.hostelName;
      applyCellStyles(row.getCell(1), 'FFFFFFFF', 'FF000000', true, 'left');
      
      const values = [hData.strength, hData.onLeave, hData.absent, hData.longAbsent, hData.hospital, hData.suspended, hData.leaveExpired, hData.totalOff, hData.present];
      values.forEach((v, i) => {
        row.getCell(i + 2).value = v || 0;
        applyCellStyles(row.getCell(i + 2), 'FFFFFFFF', 'FF000000', true);
      });
      currentRow++;
    };

    // Boys
    data.boys.forEach(addRow);
    
    // Boys Total
    const bRow = ws.getRow(currentRow);
    bRow.getCell(1).value = "TOTAL (BOYS)";
    applyCellStyles(bRow.getCell(1), 'FF404040', 'FFFFFFFF', true, 'right');
    const bValues = [totals.boysTotal.strength, totals.boysTotal.onLeave, totals.boysTotal.absent, totals.boysTotal.longAbsent, totals.boysTotal.hospital, totals.boysTotal.suspended, totals.boysTotal.leaveExpired, totals.boysTotal.totalOff, totals.boysTotal.present];
    bValues.forEach((v, i) => {
      bRow.getCell(i + 2).value = v || 0;
      applyCellStyles(bRow.getCell(i + 2), 'FF404040', 'FFFFFF00', true);
    });
    currentRow++;

    // Girls
    data.girls.forEach(addRow);

    // Girls Total
    const gRow = ws.getRow(currentRow);
    gRow.getCell(1).value = "TOTAL (GIRLS)";
    applyCellStyles(gRow.getCell(1), 'FF404040', 'FFFFFFFF', true, 'right');
    const gValues = [totals.girlsTotal.strength, totals.girlsTotal.onLeave, totals.girlsTotal.absent, totals.girlsTotal.longAbsent, totals.girlsTotal.hospital, totals.girlsTotal.suspended, totals.girlsTotal.leaveExpired, totals.girlsTotal.totalOff, totals.girlsTotal.present];
    gValues.forEach((v, i) => {
      gRow.getCell(i + 2).value = v || 0;
      applyCellStyles(gRow.getCell(i + 2), 'FF404040', 'FFFFFF00', true);
    });
    currentRow++;

    // Grand Total
    const tRow = ws.getRow(currentRow);
    tRow.getCell(1).value = "TOTAL (BOYS) + (GIRLS)";
    applyCellStyles(tRow.getCell(1), 'FF404040', 'FFFFFFFF', true, 'right');
    const tValues = [totals.grandTotal.strength, totals.grandTotal.onLeave, totals.grandTotal.absent, totals.grandTotal.longAbsent, totals.grandTotal.hospital, totals.grandTotal.suspended, totals.grandTotal.leaveExpired, totals.grandTotal.totalOff, totals.grandTotal.present];
    tValues.forEach((v, i) => {
      tRow.getCell(i + 2).value = v || 0;
      applyCellStyles(tRow.getCell(i + 2), 'FF404040', 'FFFFFF00', true);
    });
  }

  const buffer = await wb.xlsx.writeBuffer();
  saveAs(new Blob([buffer]), reportType === 'consolidated' ? `All_Hostels_Report_${todayStr}.xlsx` : `Attendance_Report_${hostelFilter}_${todayStr}.xlsx`);
};
