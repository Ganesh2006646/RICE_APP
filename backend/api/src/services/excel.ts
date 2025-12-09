import ExcelJS from 'exceljs';

export async function generateOrderExcel(order: any) {
    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet(`Order_${order.id.substring(0, 8)}`);

    // Styling
    const headerStyle = {
        font: { bold: true, size: 10 },
        alignment: { horizontal: 'center' as const, vertical: 'middle' as const },
        border: {
            top: { style: 'thin' as const },
            left: { style: 'thin' as const },
            bottom: { style: 'thin' as const },
            right: { style: 'thin' as const }
        },
        fill: {
            type: 'pattern' as const,
            pattern: 'solid' as const,
            fgColor: { argb: 'FFEEEEEE' }
        }
    };

    const cellStyle = {
        font: { size: 10 },
        border: {
            top: { style: 'thin' as const },
            left: { style: 'thin' as const },
            bottom: { style: 'thin' as const },
            right: { style: 'thin' as const }
        }
    };

    // Top Header
    worksheet.mergeCells('A1:O1');
    const titleCell = worksheet.getCell('A1');
    titleCell.value = 'OM SRI GURUBHYONAMAHA';
    titleCell.font = { bold: true, size: 12 };
    titleCell.alignment = { horizontal: 'center' };

    worksheet.mergeCells('A2:O2');
    const orderNoCell = worksheet.getCell('A2');
    orderNoCell.value = `ORDER NO - ${new Date(order.loadingDate).getFullYear()} - ${order.id.substring(0, 6).toUpperCase()}`;
    orderNoCell.font = { bold: true, size: 11 };
    orderNoCell.alignment = { horizontal: 'center' };

    worksheet.mergeCells('A3:O3');
    const dateCell = worksheet.getCell('A3');
    dateCell.value = `Loading Date: ${new Date(order.loadingDate).toLocaleDateString('en-GB')}`;
    dateCell.alignment = { horizontal: 'center' };

    // Columns
    const columns = [
        { header: 'SL', key: 'sl', width: 5 },
        { header: 'PARTY NAME', key: 'party', width: 25 },
        { header: 'PLACE', key: 'place', width: 15 },
        { header: 'TIN/GST', key: 'gst', width: 15 },
        { header: 'CELL', key: 'cell', width: 12 },
        { header: 'TYPE OF RICE', key: 'item', width: 20 },
        { header: '26 KG BAGS', key: 'bags26', width: 10 },
        { header: '26 KG QTL', key: 'qtl26', width: 10 },
        { header: '10 KG QTL', key: 'qtl10', width: 10 },
        { header: '5 KG QTL', key: 'qtl5', width: 10 },
        { header: 'QTL', key: 'totalQtl', width: 10 },
        { header: 'RATE', key: 'rate', width: 10 },
        { header: 'AMC', key: 'amc', width: 8 },
        { header: 'GST', key: 'gstPerc', width: 8 },
        { header: 'EX INFO', key: 'exInfo', width: 15 },
    ];

    // Set header row (Row 5)
    columns.forEach((col, index) => {
        const cell = worksheet.getCell(5, index + 1);
        cell.value = col.header;
        cell.style = headerStyle;
        worksheet.getColumn(index + 1).width = col.width;
    });

    // Data
    let grandTotalQtl = 0;
    let grandTotalAmount = 0;

    order.items.forEach((item: any, index: number) => {
        const qtl26 = (item.bags26 * 26) / 100;
        const qtl10 = (item.bags10 * 10) / 100;
        const qtl5 = (item.bags5 * 5) / 100;

        grandTotalQtl += item.qtyQtl;
        grandTotalAmount += item.netAmount;

        const row = worksheet.getRow(6 + index);
        row.values = [
            index + 1,
            order.customer.shopName || order.customer.name,
            order.customer.place || '',
            order.customer.tinGst || '',
            order.customer.phone || '',
            item.product.name,
            item.bags26,
            qtl26.toFixed(2),
            qtl10.toFixed(2),
            qtl5.toFixed(2),
            item.qtyQtl.toFixed(2),
            item.ratePerQtl,
            '1%',
            `${item.gstPercent}%`,
            item.netAmount.toFixed(2)
        ];

        row.eachCell((cell) => {
            cell.style = cellStyle;
            if (typeof cell.value === 'number') {
                cell.numFmt = '0.00';
            }
        });
    });

    // Totals Row
    const totalRowIdx = 6 + order.items.length;
    const totalRow = worksheet.getRow(totalRowIdx);

    // Merge first few columns for "Total" label
    worksheet.mergeCells(`A${totalRowIdx}:J${totalRowIdx}`);
    totalRow.getCell(1).value = 'TOTAL';
    totalRow.getCell(1).alignment = { horizontal: 'right' };
    totalRow.getCell(1).font = { bold: true };

    totalRow.getCell(11).value = grandTotalQtl.toFixed(2);
    totalRow.getCell(15).value = grandTotalAmount.toFixed(2);

    [11, 15].forEach(colIdx => {
        const cell = totalRow.getCell(colIdx);
        cell.font = { bold: true };
        cell.border = cellStyle.border;
    });

    return await workbook.xlsx.writeBuffer();
}
