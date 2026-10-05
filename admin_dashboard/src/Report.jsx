import React, { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import { Download, Image as ImageIcon, FileText, Globe } from 'lucide-react';
import { toPng } from 'html-to-image';
import { exportStyledExcel } from './excelExport';
import toast from 'react-hot-toast';

const API_BASE = 'http://localhost:3000/api';
const FIXED_HOSTELS = [
  "MH1-Nelson Mandela", "MH2-Bhagat Singh", "MH3-Radha Krishna", 
  "MH7", "PG-Bharati Mens hostel", "LH1", "LH2", "LH3", "LH4"
];

function Report({ user }) {
  const [data, setData] = useState({ students: [], records: [], wardens: [], leaves: [] });
  const [reportType, setReportType] = useState(user?.role === 'hostel_admin' ? 'individual' : 'consolidated');
  const [hostelFilter, setHostelFilter] = useState(user?.role === 'hostel_admin' ? user.hostel_name : FIXED_HOSTELS[0]);
  const [loading, setLoading] = useState(true);
  const reportRef = useRef(null);

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [detailedRes, wardensRes, leavesRes] = await Promise.all([
        axios.get(`${API_BASE}/admin/detailed_students`),
        axios.get(`${API_BASE}/admin/wardens`),
        axios.get(`${API_BASE}/admin/leaves`)
      ]);
      setData({
        students: detailedRes.data.students || [],
        records: detailedRes.data.records || [],
        wardens: wardensRes.data || [],
        leaves: leavesRes.data || []
      });
    } catch (err) {
      toast.error('Failed to load report data');
      console.error(err);
    }
    setLoading(false);
  };

  const getselectedDate = () => {
    const d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  };

  const [selectedDate, setSelectedDate] = useState(getselectedDate());

  // ----- LOGIC FOR INDIVIDUAL HOSTEL REPORT -----
  const processIndividualReport = () => {
    const hostelWardens = data.wardens.filter(w => w.hostel_name === hostelFilter);
    const rows = [];
    let totalStrengthSum = 0;
    let leaveSum = 0;
    let absentSum = 0;
    let presentSum = 0;
    const todayRecords = data.records.filter(r => r.timestamp.startsWith(selectedDate));

    hostelWardens.forEach(warden => {
      const wStudents = data.students.filter(s => s.warden_email === warden.email);
      if (wStudents.length === 0) return;
      const totalStrength = wStudents.length;
      totalStrengthSum += totalStrength;

      const rooms = [...new Set(wStudents.map(s => s.room_name).filter(Boolean))];
      let roomDisplay = '';
      if (rooms.length > 0) {
        rooms.sort((a, b) => a.localeCompare(b, undefined, {numeric: true}));
        if (rooms.length === 1) roomDisplay = rooms[0];
        else roomDisplay = `${rooms[0]} - ${rooms[rooms.length - 1]}`;
      }

      let onLeaveCount = 0;
      let presentCount = 0;
      let absentWoPermissionCount = 0;

      wStudents.forEach(student => {
        const hasLeave = data.leaves.some(l => {
          if (l.register_number !== student.studentId) return false;
          if (l.status !== 'APPROVED') return false;
          const from = l.from_date.split('T')[0];
          const to = l.to_date.split('T')[0];
          return selectedDate >= from && selectedDate <= to;
        });

        const studentRoom = student.room_name || 'unknown';
        const roomRecords = todayRecords.filter(r => r.room_name === studentRoom);
        
        let isPresent = false;
        for (const record of roomRecords) {
          if (record.present_students?.some(p => 
            p.id === student.local_id || p.id === student.db_id || 
            p.studentId === student.studentId || p.name === student.name
          )) {
            isPresent = true;
            break;
          }
        }

        if (isPresent) {
          presentCount++;
        } else if (hasLeave) {
          onLeaveCount++;
        } else {
          absentWoPermissionCount++;
        }
      });

      leaveSum += onLeaveCount;
      presentSum += presentCount;
      absentSum += absentWoPermissionCount;

      rows.push({ wardenName: warden.name || 'Unknown', roomDisplay, totalStrength, leave: onLeaveCount, suspend: 0, longLeave: 0, absentWoPermission: absentWoPermissionCount, leaveExpired: 0, hospital: 0, present: presentCount });
    });

    return { rows, totals: { totalStrengthSum, leaveSum, absentSum, presentSum } };
  };

  // ----- LOGIC FOR CONSOLIDATED REPORT -----
  const processConsolidatedReport = () => {
    const todayRecords = data.records.filter(r => r.timestamp.startsWith(selectedDate));
    const processedHostels = FIXED_HOSTELS.map(hostelName => {
      const hStudents = data.students.filter(s => s.hostel_name === hostelName);
      let onLeaveCount = 0, presentCount = 0, absentWoPermissionCount = 0;

      hStudents.forEach(student => {
        const hasLeave = data.leaves.some(l => {
          if (l.register_number !== student.studentId) return false;
          if (l.status !== 'APPROVED') return false;
          const from = l.from_date.split('T')[0];
          const to = l.to_date.split('T')[0];
          return selectedDate >= from && selectedDate <= to;
        });
        const studentRoom = student.room_name || 'unknown';
        const roomRecords = todayRecords.filter(r => r.room_name === studentRoom);
        let isPresent = false;
        for (const record of roomRecords) {
          if (record.present_students?.some(p => 
            p.id === student.local_id || p.id === student.db_id || 
            p.studentId === student.studentId || p.name === student.name
          )) {
            isPresent = true;
            break;
          }
        }
        if (isPresent) presentCount++;
        else if (hasLeave) onLeaveCount++;
        else absentWoPermissionCount++;
      });

      return {
        hostelName,
        isGirls: hostelName.startsWith('LH'),
        strength: hStudents.length,
        onLeave: onLeaveCount,
        absent: absentWoPermissionCount,
        longAbsent: 0, hospital: 0, suspended: 0, leaveExpired: 0,
        totalOff: onLeaveCount + absentWoPermissionCount,
        present: presentCount
      };
    });

    const boys = processedHostels.filter(h => !h.isGirls);
    const girls = processedHostels.filter(h => h.isGirls);
    
    const sumArray = (arr, key) => arr.reduce((sum, item) => sum + (item[key] || 0), 0);
    const getTotals = (arr) => ({
      strength: sumArray(arr, 'strength'),
      onLeave: sumArray(arr, 'onLeave'),
      absent: sumArray(arr, 'absent'),
      longAbsent: 0, hospital: 0, suspended: 0, leaveExpired: 0,
      totalOff: sumArray(arr, 'totalOff'),
      present: sumArray(arr, 'present')
    });

    return { boys, girls, boysTotal: getTotals(boys), girlsTotal: getTotals(girls), grandTotal: getTotals(processedHostels) };
  };

  const indData = processIndividualReport();
  const conData = processConsolidatedReport();

  const downloadImage = async () => {
    if (!reportRef.current) return;
    try {
      const url = await toPng(reportRef.current, { cacheBust: true, pixelRatio: 2 });
      const link = document.createElement('a');
      link.download = reportType === 'consolidated' ? `All_Hostels_Report_${selectedDate}.png` : `Attendance_Report_${hostelFilter}_${selectedDate}.png`;
      link.href = url;
      link.click();
      toast.success('Image downloaded');
    } catch (err) {
      console.error('Image Export Error:', err);
      toast.error(`Failed to generate image: ${err.message || 'Unknown error'}`);
    }
  };

  const downloadExcel = async () => {
    try {
      await exportStyledExcel(reportType, hostelFilter, selectedDate, { rows: indData.rows, boys: conData.boys, girls: conData.girls }, { ...indData.totals, boysTotal: conData.boysTotal, girlsTotal: conData.girlsTotal, grandTotal: conData.grandTotal });
      toast.success('Excel downloaded');
    } catch (err) {
      console.error('Excel Export Error:', err);
      toast.error('Failed to generate Excel file');
    }
  };

  if (loading) return <div className="p-8">Loading report data...</div>;

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <h2 className="text-2xl font-bold text-gray-900 tracking-tight">Daily Attendance Report</h2>
        <div className="flex items-center space-x-3">
          <button onClick={downloadImage} className="flex items-center px-4 py-2 bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 shadow-sm text-sm font-medium transition-colors">
            <ImageIcon className="w-4 h-4 mr-2" /> Image
          </button>
          <button onClick={downloadExcel} className="flex items-center px-4 py-2 bg-green-600 text-white rounded-xl hover:bg-green-700 shadow-sm text-sm font-medium transition-colors">
            <Download className="w-4 h-4 mr-2" /> Excel
          </button>
        </div>
      </div>

      {/* Control Panel */}
      <div className="bg-white p-4 rounded-xl shadow-sm border border-gray-100 flex flex-col md:flex-row items-center gap-6">
        <div className="flex items-center space-x-3">
          <label className="text-sm font-semibold text-gray-600">Date:</label>
          <input 
            type="date" 
            value={selectedDate} 
            onChange={(e) => setSelectedDate(e.target.value)} 
            className="border border-gray-200 rounded-lg px-3 py-1.5 text-sm outline-none focus:ring-2 focus:ring-blue-500 font-medium"
          />
        </div>

        {user?.role === 'super_admin' && (
          <div className="flex bg-gray-100 p-1 rounded-lg md:ml-4">
            <button onClick={() => setReportType('consolidated')} className={`flex items-center px-4 py-2 text-sm font-semibold rounded-md transition-all ${reportType === 'consolidated' ? 'bg-white text-blue-800 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}>
              <Globe className="w-4 h-4 mr-2" /> Campus Overview
            </button>
            <button onClick={() => setReportType('individual')} className={`flex items-center px-4 py-2 text-sm font-semibold rounded-md transition-all ${reportType === 'individual' ? 'bg-white text-blue-800 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}>
              <FileText className="w-4 h-4 mr-2" /> Specific Hostel
            </button>
          </div>
        )}
        
        {reportType === 'individual' && user?.role === 'super_admin' && (
          <div className="flex items-center space-x-3 border-l pl-6 border-gray-200">
            <label className="text-sm font-semibold text-gray-600">Select Hostel:</label>
            <select value={hostelFilter} onChange={e => setHostelFilter(e.target.value)} className="border border-gray-200 rounded-lg px-3 py-1.5 text-sm outline-none focus:ring-2 focus:ring-blue-500 font-medium">
              {FIXED_HOSTELS.map(h => <option key={h} value={h}>{h}</option>)}
            </select>
          </div>
        )}
      </div>

      {/* Report Preview Container */}
      <div className="overflow-x-auto bg-gray-50 p-8 rounded-2xl border border-gray-200 shadow-inner flex justify-center">
        
        {/* === INDIVIDUAL HOSTEL RENDER === */}
        {reportType === 'individual' && (
          <div ref={reportRef} className="bg-white border-2 border-blue-800" style={{ width: '1000px' }}>
            <div className="bg-white border-b-2 border-blue-800">
              <img src="/kare_header.jpg" alt="KARE Header" className="w-full h-auto object-contain" />
            </div>
            <div className="text-center py-2 bg-yellow-300 border-b border-gray-400">
              <h2 className="text-xl font-bold text-blue-800">{hostelFilter.toUpperCase()}</h2>
            </div>
            <div className="text-center py-1.5 bg-orange-100 border-b border-gray-400">
              <h3 className="text-lg font-bold text-red-600">{selectedDate.split('-').reverse().join('.')}</h3>
            </div>
            <table className="w-full text-center border-collapse">
              <thead>
                <tr className="bg-blue-100 text-blue-900 font-bold text-sm">
                  <th className="border border-gray-400 p-2 w-48">NAME OF THE CT AND AW</th>
                  <th className="border border-gray-400 p-2 w-24">ROOM NUMBER</th>
                  <th className="border border-gray-400 p-2 w-24">TOTAL STUDENT STRENGTH</th>
                  <th className="border border-gray-400 p-2"><div style={{writingMode: 'vertical-rl', transform: 'rotate(180deg)'}} className="mx-auto text-red-600 h-24 flex items-center">LEAVE</div></th>
                  <th className="border border-gray-400 p-2"><div style={{writingMode: 'vertical-rl', transform: 'rotate(180deg)'}} className="mx-auto text-yellow-700 h-24 flex items-center">SUSPEND</div></th>
                  <th className="border border-gray-400 p-2"><div style={{writingMode: 'vertical-rl', transform: 'rotate(180deg)'}} className="mx-auto text-yellow-700 h-24 flex items-center">LONG LEAVE</div></th>
                  <th className="border border-gray-400 p-2"><div style={{writingMode: 'vertical-rl', transform: 'rotate(180deg)'}} className="mx-auto text-red-600 h-24 flex items-center">ABSENT W/O PERMISSION</div></th>
                  <th className="border border-gray-400 p-2"><div style={{writingMode: 'vertical-rl', transform: 'rotate(180deg)'}} className="mx-auto text-yellow-700 h-24 flex items-center">LEAVE EXPERID</div></th>
                  <th className="border border-gray-400 p-2"><div style={{writingMode: 'vertical-rl', transform: 'rotate(180deg)'}} className="mx-auto text-yellow-700 h-24 flex items-center">HOSPITAL</div></th>
                  <th className="border border-gray-400 p-2 w-24">STUDENT PRESENT IN HOSTEL</th>
                </tr>
              </thead>
              <tbody className="bg-white">
                {indData.rows.map((r, idx) => (
                  <tr key={idx} className={idx % 2 === 0 ? "bg-yellow-50" : "bg-blue-50"}>
                    <td className="border border-gray-400 p-2 text-left font-bold text-blue-800 text-sm pl-4 uppercase">{r.wardenName}</td>
                    <td className="border border-gray-400 p-2 font-bold text-blue-900">{r.roomDisplay}</td>
                    <td className="border border-gray-400 p-2 font-bold text-blue-900">{r.totalStrength}</td>
                    <td className="border border-gray-400 p-2 font-bold text-red-600">{r.leave || ''}</td>
                    <td className="border border-gray-400 p-2 font-bold text-yellow-700">{r.suspend || ''}</td>
                    <td className="border border-gray-400 p-2 font-bold text-yellow-700">{r.longLeave || ''}</td>
                    <td className="border border-gray-400 p-2 font-bold text-red-600">{r.absentWoPermission || ''}</td>
                    <td className="border border-gray-400 p-2 font-bold text-yellow-700">{r.leaveExpired || ''}</td>
                    <td className="border border-gray-400 p-2 font-bold text-yellow-700">{r.hospital || ''}</td>
                    <td className="border border-gray-400 p-2 font-bold text-blue-900">{r.present || ''}</td>
                  </tr>
                ))}
                <tr className="bg-cyan-500 text-blue-900 font-bold">
                  <td className="border border-gray-400 p-2 text-right pr-10" colSpan="2">TOTAL</td>
                  <td className="border border-gray-400 p-2">{indData.totals.totalStrengthSum}</td>
                  <td className="border border-gray-400 p-2">{indData.totals.leaveSum || ''}</td>
                  <td className="border border-gray-400 p-2"></td>
                  <td className="border border-gray-400 p-2"></td>
                  <td className="border border-gray-400 p-2">{indData.totals.absentSum || ''}</td>
                  <td className="border border-gray-400 p-2"></td>
                  <td className="border border-gray-400 p-2"></td>
                  <td className="border border-gray-400 p-2">{indData.totals.presentSum || ''}</td>
                </tr>
              </tbody>
            </table>
          </div>
        )}

        {/* === CONSOLIDATED CAMPUS RENDER === */}
        {reportType === 'consolidated' && (
          <div ref={reportRef} className="bg-white border-[6px] border-green-500" style={{ width: '900px' }}>
            <div className="bg-white border-b-2 border-blue-800">
              <img src="/kare_header.jpg" alt="KARE Header" className="w-full h-auto object-contain" />
            </div>
            <div className="text-center py-2 bg-purple-100 border-b border-gray-400">
              <h2 className="text-xl font-bold text-gray-900">KARE - ALL HOSTEL REPORT</h2>
            </div>
            <div className="text-center py-1.5 bg-blue-100 border-b-4 border-purple-800">
              <h3 className="text-lg font-bold text-[#1e3a8a]">DAILY ATTENDANCE FOR STUDENTS DT :- {selectedDate.split('-').reverse().join(' ')}</h3>
            </div>
            
            <table className="w-full text-center border-collapse">
              <thead>
                <tr className="bg-white font-bold text-sm text-[#1e3a8a]">
                  <th className="border border-gray-500 p-3 text-center">NAME OF THE HOSTELS</th>
                  <th className="border border-gray-500 p-2 w-24">PRESENTLY AVALIBLE<br/>STRENGTH</th>
                  <th className="border border-gray-500 p-2"><div style={{writingMode: 'vertical-rl', transform: 'rotate(180deg)'}} className="mx-auto h-28 flex items-center">ON LEAVE</div></th>
                  <th className="border border-gray-500 p-2"><div style={{writingMode: 'vertical-rl', transform: 'rotate(180deg)'}} className="mx-auto h-28 flex items-center">ABSENT W/O<br/>PERMISSION</div></th>
                  <th className="border border-gray-500 p-2"><div style={{writingMode: 'vertical-rl', transform: 'rotate(180deg)'}} className="mx-auto h-28 flex items-center">LONG ABSENT</div></th>
                  <th className="border border-gray-500 p-2"><div style={{writingMode: 'vertical-rl', transform: 'rotate(180deg)'}} className="mx-auto h-28 flex items-center">HOSPITAL</div></th>
                  <th className="border border-gray-500 p-2"><div style={{writingMode: 'vertical-rl', transform: 'rotate(180deg)'}} className="mx-auto h-28 flex items-center">SUSPENDED</div></th>
                  <th className="border border-gray-500 p-2 bg-pink-600 text-yellow-300"><div style={{writingMode: 'vertical-rl', transform: 'rotate(180deg)'}} className="mx-auto h-28 flex items-center">LEAVE EXPIRED</div></th>
                  <th className="border border-gray-500 p-2 text-black">TOTAL<br/>OFF</th>
                  <th className="border border-gray-500 p-2 w-28">STUDENT<br/>PRESENT<br/>IN HOSTEL</th>
                </tr>
              </thead>
              <tbody className="bg-white text-black font-bold">
                {conData.boys.map((h, i) => (
                  <tr key={i}>
                    <td className="border border-gray-500 p-2 text-left pl-4">{h.hostelName}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.strength}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.onLeave}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.absent}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.longAbsent}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.hospital}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.suspended}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.leaveExpired}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.totalOff}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.present}</td>
                  </tr>
                ))}
                <tr className="bg-gray-700 text-white border-b-4 border-green-500">
                  <td className="border border-gray-500 p-2 text-right pr-6 font-bold text-lg">TOTAL <span className="text-red-400">(BOYS)</span></td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.boysTotal.strength}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.boysTotal.onLeave}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.boysTotal.absent}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.boysTotal.longAbsent}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.boysTotal.hospital}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.boysTotal.suspended}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.boysTotal.leaveExpired}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.boysTotal.totalOff}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.boysTotal.present}</td>
                </tr>
                {conData.girls.map((h, i) => (
                  <tr key={i}>
                    <td className="border border-gray-500 p-2 text-left pl-4">{h.hostelName}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.strength}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.onLeave}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.absent}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.longAbsent}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.hospital}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.suspended}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.leaveExpired}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.totalOff}</td>
                    <td className="border border-gray-500 p-2 text-lg">{h.present}</td>
                  </tr>
                ))}
                <tr className="bg-gray-700 text-white border-b-4 border-green-500">
                  <td className="border border-gray-500 p-2 text-right pr-6 font-bold text-lg">TOTAL <span className="text-red-400">(GIRLS)</span></td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.girlsTotal.strength}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.girlsTotal.onLeave}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.girlsTotal.absent}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.girlsTotal.longAbsent}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.girlsTotal.hospital}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.girlsTotal.suspended}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.girlsTotal.leaveExpired}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.girlsTotal.totalOff}</td>
                  <td className="border border-gray-500 p-2 text-yellow-400 text-xl">{conData.girlsTotal.present}</td>
                </tr>
                <tr className="bg-gray-700 text-white">
                  <td className="border border-gray-500 p-3 text-right pr-6 font-bold text-xl">TOTAL <span className="text-white">(BOYS)</span> <span className="text-red-400">+</span> <span className="text-white">(GIRLS)</span></td>
                  <td className="border border-gray-500 p-3 text-yellow-400 text-2xl">{conData.grandTotal.strength}</td>
                  <td className="border border-gray-500 p-3 text-yellow-400 text-2xl">{conData.grandTotal.onLeave}</td>
                  <td className="border border-gray-500 p-3 text-yellow-400 text-2xl">{conData.grandTotal.absent}</td>
                  <td className="border border-gray-500 p-3 text-yellow-400 text-2xl">{conData.grandTotal.longAbsent}</td>
                  <td className="border border-gray-500 p-3 text-yellow-400 text-2xl">{conData.grandTotal.hospital}</td>
                  <td className="border border-gray-500 p-3 text-yellow-400 text-2xl">{conData.grandTotal.suspended}</td>
                  <td className="border border-gray-500 p-3 text-yellow-400 text-2xl">{conData.grandTotal.leaveExpired}</td>
                  <td className="border border-gray-500 p-3 text-yellow-400 text-2xl">{conData.grandTotal.totalOff}</td>
                  <td className="border border-gray-500 p-3 text-yellow-400 text-2xl">{conData.grandTotal.present}</td>
                </tr>
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

export default Report;
