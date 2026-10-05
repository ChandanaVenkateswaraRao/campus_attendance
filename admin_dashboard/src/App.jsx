import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { BrowserRouter as Router, Routes, Route, Link, useNavigate, useLocation } from 'react-router-dom';
import { LayoutDashboard, Users, ClipboardList, LogOut, Search, RefreshCw, X, Building, Grid, Layers, Hash, Calendar, GraduationCap, Edit2, Trash2 } from 'lucide-react';
import toast, { Toaster } from 'react-hot-toast';
import LeavesAndOutings from './LeavesAndOutings';
import Report from './Report';

const API_BASE = 'http://localhost:3000/api';

const FIXED_HOSTELS = [
  "MH1-Nelson Mandela",
  "MH2-Bhagat Singh",
  "MH3-Radha Krishna",
  "MH7",
  "PG-Bharati Mens hostel",
  "LH1",
  "LH2",
  "LH3",
  "LH4"
];

const confirmAction = (message, onConfirm) => {
  toast((t) => (
    <div className="flex flex-col space-y-3">
      <span className="text-sm font-medium text-gray-800">{message}</span>
      <div className="flex space-x-2 justify-end mt-2">
        <button 
          onClick={() => {
            toast.dismiss(t.id);
            onConfirm();
          }} 
          className="bg-[#1e3a8a] text-white px-4 py-2 rounded-xl text-xs font-semibold hover:bg-[#1e40af] transition-colors shadow-sm shadow-blue-900/20"
        >
          Confirm
        </button>
        <button 
          onClick={() => toast.dismiss(t.id)} 
          className="bg-gray-100 text-gray-700 px-4 py-2 rounded-xl text-xs font-semibold hover:bg-gray-200 transition-colors"
        >
          Cancel
        </button>
      </div>
    </div>
  ), { duration: Infinity, position: 'top-center', style: { minWidth: '300px', padding: '16px', borderRadius: '16px' } });
};

function FilterDropdown({ label, icon: Icon, value, onChange, options, defaultOption }) {
  return (
    <div className="flex-1 min-w-[140px]">
      <label className="flex items-center text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">
        {Icon && <Icon className="w-3 h-3 mr-1.5" />} {label}
      </label>
      <select 
        className="w-full bg-white border border-gray-200 text-gray-700 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-[#1e3a8a] focus:border-transparent outline-none transition-all shadow-sm appearance-none cursor-pointer"
        value={value} 
        onChange={e => onChange(e.target.value)}
      >
        <option value="">{defaultOption}</option>
        {options.map(opt => <option key={opt} value={opt}>{opt}</option>)}
      </select>
    </div>
  );
}

function SearchInput({ label, value, onChange, placeholder }) {
  return (
    <div className="flex-1 min-w-[180px]">
      <label className="flex items-center text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">
        <Search className="w-3 h-3 mr-1.5" /> {label}
      </label>
      <input 
        type="text" 
        placeholder={placeholder}
        className="w-full bg-white border border-gray-200 text-gray-800 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-[#1e3a8a] focus:border-transparent outline-none transition-all shadow-sm"
        value={value} 
        onChange={e => onChange(e.target.value)}
      />
    </div>
  );
}

function Dashboard({ user }) {
  const [allStudents, setAllStudents] = useState([]);
  const [allRecords, setAllRecords] = useState([]);
  const [allWardens, setAllWardens] = useState([]);
  const [loading, setLoading] = useState(true);

  // Filters
  const [hostelFilter, setHostelFilter] = useState(user?.role === 'hostel_admin' ? user.hostel_name : '');
  const [blockFilter, setBlockFilter] = useState('');
  const [floorFilter, setFloorFilter] = useState('');
  const [roomFilter, setRoomFilter] = useState('');
  const [searchRegister, setSearchRegister] = useState('');
  const [daysCount, setDaysCount] = useState(10);

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [detailedRes, wardensRes] = await Promise.all([
        axios.get(`${API_BASE}/admin/detailed_students`),
        axios.get(`${API_BASE}/admin/wardens`)
      ]);
      setAllStudents(detailedRes.data.students || []);
      setAllRecords(detailedRes.data.records || []);
      setAllWardens(wardensRes.data || []);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching data:', error);
      setLoading(false);
    }
  };

  const uniqueHostels = FIXED_HOSTELS;
  const uniqueBlocks = [...new Set(allWardens.filter(w => !hostelFilter || w.hostel_name === hostelFilter).map(w => w.block_name).filter(Boolean))];
  const uniqueFloors = [...new Set(allWardens.filter(w => (!hostelFilter || w.hostel_name === hostelFilter) && (!blockFilter || w.block_name === blockFilter)).map(w => w.floor_number).filter(Boolean))];
  const uniqueRooms = [...new Set(allStudents.filter(s => {
    if (hostelFilter && s.hostel_name !== hostelFilter) return false;
    if (blockFilter && s.block_name !== blockFilter) return false;
    if (floorFilter && s.floor_number !== floorFilter) return false;
    return true;
  }).map(s => s.room_name).filter(Boolean))].sort((a, b) => a.localeCompare(b, undefined, {numeric: true}));

  const filteredStudents = allStudents.filter(s => {
    if (hostelFilter && s.hostel_name !== hostelFilter) return false;
    if (blockFilter && s.block_name !== blockFilter) return false;
    if (floorFilter && s.floor_number !== floorFilter) return false;
    if (roomFilter && s.room_name !== roomFilter) return false;
    if (searchRegister && s.studentId && !s.studentId.toLowerCase().includes(searchRegister.toLowerCase())) return false;
    return true;
  });

  const dates = [];
  for (let i = 0; i < daysCount; i++) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const localDate = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
    dates.push(localDate);
  }

  const getAttendanceStatus = (student, dateStr) => {
    const sRoom = student.room_name || 'unknown';
    const dailyRecords = allRecords.filter(r => r.timestamp.startsWith(dateStr) && (r.room_name === sRoom));
    if (dailyRecords.length === 0) return 'NO_DATA';

    for (const record of dailyRecords) {
      if (!record.present_students) continue;
      const found = record.present_students.some(p => {
        if (typeof p === 'string') return p === student.studentId || p === student.name;
        return p.studentId === student.studentId || p.id === student.local_id || p.id === student.db_id || p.name === student.name;
      });
      if (found) return 'PRESENT';
    }
    return 'ABSENT';
  };

  const clearFilters = () => {
    setHostelFilter(user?.role === 'hostel_admin' ? user.hostel_name : ''); 
    setBlockFilter(''); setFloorFilter(''); setRoomFilter(''); setSearchRegister(''); setDaysCount(10);
  };

  const toggleAttendance = async (student, date, currentStatus) => {
    let actionText = 'MARK PRESENT';
    if (currentStatus === 'PRESENT') actionText = 'MARK ABSENT';
    else if (currentStatus === 'ABSENT') actionText = 'MARK PRESENT';
    else if (currentStatus === 'NO_DATA') actionText = 'CREATE RECORD & MARK PRESENT';

    confirmAction(`Are you sure you want to ${actionText} for ${student.name} on ${date}?`, async () => {
      try {
        await axios.post(`${API_BASE}/admin/attendance/toggle`, {
          date,
          room_name: student.room_name || 'unknown',
          student: { db_id: student.db_id, local_id: student.local_id, studentId: student.studentId, name: student.name }
        });
        toast.success(`Attendance updated for ${student.name}`);
        fetchData(); // Refresh the table
      } catch (err) {
        toast.error('Error updating attendance');
        console.error(err);
      }
    });
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-gray-900 tracking-tight">Attendance Dashboard</h2>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        {/* Filters Header */}
        <div className="bg-gray-50/50 p-5 border-b border-gray-100">
          <div className="flex flex-wrap gap-4 items-end">
            {user?.role === 'super_admin' && (
              <FilterDropdown label="Hostel" icon={Building} value={hostelFilter} onChange={setHostelFilter} options={uniqueHostels} defaultOption="All Hostels" />
            )}
            <FilterDropdown label="Block" icon={Grid} value={blockFilter} onChange={setBlockFilter} options={uniqueBlocks} defaultOption="All Blocks" />
            <FilterDropdown label="Floor" icon={Layers} value={floorFilter} onChange={setFloorFilter} options={uniqueFloors} defaultOption="All Floors" />
            <FilterDropdown label="Room" icon={Hash} value={roomFilter} onChange={setRoomFilter} options={uniqueRooms} defaultOption="All Rooms" />
            
            <SearchInput label="Search Register No" value={searchRegister} onChange={setSearchRegister} placeholder="e.g. 12345" />

            <div className="flex-1 min-w-[120px]">
              <label className="flex items-center text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">
                <Calendar className="w-3 h-3 mr-1.5" /> Days
              </label>
              <input type="number" min="1" max="30" className="w-full bg-white border border-gray-200 text-gray-800 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-[#1e3a8a] focus:border-transparent outline-none transition-all shadow-sm" value={daysCount} onChange={(e) => setDaysCount(Number(e.target.value))} />
            </div>

            <div className="flex items-center space-x-3 ml-auto mt-2">
              <button onClick={clearFilters} className="flex items-center px-4 py-2 bg-gray-100 text-gray-700 rounded-xl hover:bg-gray-200 transition-colors text-sm font-medium">
                <X className="w-4 h-4 mr-1.5"/> Clear
              </button>
              <button onClick={fetchData} className="flex items-center px-4 py-2 bg-[#1e3a8a] text-white rounded-xl hover:bg-[#1e40af] shadow-md shadow-blue-900/20 transition-colors text-sm font-medium">
                <RefreshCw className="w-4 h-4 mr-1.5" /> Refresh
              </button>
            </div>
          </div>
        </div>

        {/* Table Content */}
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex flex-col items-center">
            <RefreshCw className="w-8 h-8 animate-spin mb-4 text-blue-500" />
            <p>Loading attendance data...</p>
          </div>
        ) : filteredStudents.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <div className="bg-gray-50 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
              <Search className="w-6 h-6 text-gray-400" />
            </div>
            <p>No students found for the selected filters.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse whitespace-nowrap">
              <thead>
                <tr className="bg-white text-gray-500 text-xs font-semibold uppercase tracking-wider border-b border-gray-100">
                  <th className="py-4 px-5">S.No.</th>
                  <th className="py-4 px-5">Student Info</th>
                  <th className="py-4 px-5">Location</th>
                  {dates.map(date => (
                    <th key={date} className="py-4 px-3 text-center" title={date}>
                      {date.substring(5).replace('-', '/')}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {filteredStudents.map((student, idx) => (
                  <tr key={student.db_id} className="hover:bg-blue-50/40 transition-colors group">
                    <td className="py-3 px-5 text-sm text-gray-500">{idx + 1}</td>
                    <td className="py-3 px-5">
                      <div className="flex flex-col">
                        <span className="text-sm font-semibold text-gray-900">{student.name}</span>
                        <span className="text-xs text-gray-500">{student.studentId || '-'}</span>
                      </div>
                    </td>
                    <td className="py-3 px-5">
                      <div className="flex flex-col">
                        <span className="text-sm font-medium text-gray-700">{student.hostel_name || 'Unassigned'}</span>
                        <span className="text-xs text-gray-500">Room: {student.room_name || '-'}</span>
                      </div>
                    </td>
                    {dates.map(date => {
                      const status = getAttendanceStatus(student, date);
                      return (
                        <td 
                          key={date} 
                          className="py-3 px-3 text-center cursor-pointer hover:bg-blue-50 transition-colors" 
                          onClick={() => toggleAttendance(student, date, status)}
                          title={status === 'NO_DATA' ? 'No Data - Click to mark present' : 'Click to toggle attendance'}
                        >
                          {status === 'PRESENT' ? (
                            <div className="w-6 h-6 rounded-full bg-green-100 text-green-600 flex items-center justify-center mx-auto hover:bg-green-200 transition-colors">
                              <div className="w-2 h-2 rounded-full bg-green-500"></div>
                            </div>
                          ) : status === 'ABSENT' ? (
                            <div className="w-6 h-6 rounded-full bg-blue-50 text-red-400 flex items-center justify-center mx-auto hover:bg-red-100 transition-colors">
                              <div className="w-1.5 h-1.5 rounded-full bg-red-400"></div>
                            </div>
                          ) : (
                            <div className="w-6 h-6 rounded-full bg-gray-50 text-gray-400 flex items-center justify-center mx-auto hover:bg-gray-200 transition-colors border border-dashed border-gray-300">
                              <span className="text-xs font-bold leading-none mt-[2px]">-</span>
                            </div>
                          )}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

function StudentDetails({ user }) {
  const [allStudents, setAllStudents] = useState([]);
  const [allWardens, setAllWardens] = useState([]);
  const [loading, setLoading] = useState(true);

  // Filters
  const [hostelFilter, setHostelFilter] = useState(user?.role === 'hostel_admin' ? user.hostel_name : '');
  const [blockFilter, setBlockFilter] = useState('');
  const [floorFilter, setFloorFilter] = useState('');
  const [roomFilter, setRoomFilter] = useState('');
  const [searchRegister, setSearchRegister] = useState('');

  // Editing state
  const [editingStudent, setEditingStudent] = useState(null);
  const [formData, setFormData] = useState({});

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [detailedRes, wardensRes] = await Promise.all([
        axios.get(`${API_BASE}/admin/detailed_students`),
        axios.get(`${API_BASE}/admin/wardens`)
      ]);
      setAllStudents(detailedRes.data.students || []);
      setAllWardens(wardensRes.data || []);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching data:', error);
      setLoading(false);
    }
  };

  const uniqueHostels = FIXED_HOSTELS;
  const uniqueBlocks = [...new Set(allWardens.filter(w => !hostelFilter || w.hostel_name === hostelFilter).map(w => w.block_name).filter(Boolean))];
  const uniqueFloors = [...new Set(allWardens.filter(w => (!hostelFilter || w.hostel_name === hostelFilter) && (!blockFilter || w.block_name === blockFilter)).map(w => w.floor_number).filter(Boolean))];
  const uniqueRooms = [...new Set(allStudents.filter(s => {
    if (hostelFilter && s.hostel_name !== hostelFilter) return false;
    if (blockFilter && s.block_name !== blockFilter) return false;
    if (floorFilter && s.floor_number !== floorFilter) return false;
    return true;
  }).map(s => s.room_name).filter(Boolean))].sort((a, b) => a.localeCompare(b, undefined, {numeric: true}));

  const filteredStudents = allStudents.filter(s => {
    if (hostelFilter && s.hostel_name !== hostelFilter) return false;
    if (blockFilter && s.block_name !== blockFilter) return false;
    if (floorFilter && s.floor_number !== floorFilter) return false;
    if (roomFilter && s.room_name !== roomFilter) return false;
    if (searchRegister && s.studentId && !s.studentId.toLowerCase().includes(searchRegister.toLowerCase())) return false;
    return true;
  });

  const clearFilters = () => {
    setHostelFilter(user?.role === 'hostel_admin' ? user.hostel_name : ''); 
    setBlockFilter(''); setFloorFilter(''); setRoomFilter(''); setSearchRegister('');
  };

  const handleEdit = (student) => {
    setEditingStudent(student.db_id);
    setFormData({ ...student });
  };

  const handleSave = async (e) => {
    e.preventDefault();
    try {
      await axios.put(`${API_BASE}/admin/students/${editingStudent}`, formData);
      setEditingStudent(null);
      fetchData();
    } catch(err) {
      alert('Error saving student');
    }
  };

  const handleDelete = async (db_id) => {
    confirmAction('Are you sure you want to delete this student?', async () => {
      try {
        await axios.delete(`${API_BASE}/admin/students/${db_id}`);
        toast.success('Student deleted successfully');
        fetchData();
      } catch(err) {
        toast.error('Error deleting student');
      }
    });
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-gray-900 tracking-tight">Student Details</h2>
      </div>

      {editingStudent && (
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-800 mb-4">Edit Student</h3>
          <form onSubmit={handleSave} className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Name</label>
              <input type="text" className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a]" value={formData.name || ''} onChange={e => setFormData({...formData, name: e.target.value})} />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Register No.</label>
              <input type="text" className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a]" value={formData.studentId || ''} onChange={e => setFormData({...formData, studentId: e.target.value})} />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Email</label>
              <input type="email" className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a]" value={formData.email || ''} onChange={e => setFormData({...formData, email: e.target.value})} />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Phone Number</label>
              <input type="text" className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a]" value={formData.phone_number || ''} onChange={e => setFormData({...formData, phone_number: e.target.value})} />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Father Phone</label>
              <input type="text" className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a]" value={formData.father_phone_number || ''} onChange={e => setFormData({...formData, father_phone_number: e.target.value})} />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Mother Phone</label>
              <input type="text" className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a]" value={formData.mother_phone_number || ''} onChange={e => setFormData({...formData, mother_phone_number: e.target.value})} />
            </div>
            <div className="col-span-full mt-2 flex space-x-3">
              <button type="submit" className="bg-[#1e3a8a] text-white px-5 py-2 rounded-xl text-sm font-medium hover:bg-[#1e40af]">Save</button>
              <button type="button" onClick={() => setEditingStudent(null)} className="bg-gray-100 text-gray-700 px-5 py-2 rounded-xl text-sm font-medium hover:bg-gray-200">Cancel</button>
            </div>
          </form>
        </div>
      )}

      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        {/* Filters Header */}
        <div className="bg-gray-50/50 p-5 border-b border-gray-100">
          <div className="flex flex-wrap gap-4 items-end">
            {user?.role === 'super_admin' && (
              <FilterDropdown label="Hostel" icon={Building} value={hostelFilter} onChange={setHostelFilter} options={uniqueHostels} defaultOption="All Hostels" />
            )}
            <FilterDropdown label="Block" icon={Grid} value={blockFilter} onChange={setBlockFilter} options={uniqueBlocks} defaultOption="All Blocks" />
            <FilterDropdown label="Floor" icon={Layers} value={floorFilter} onChange={setFloorFilter} options={uniqueFloors} defaultOption="All Floors" />
            <FilterDropdown label="Room" icon={Hash} value={roomFilter} onChange={setRoomFilter} options={uniqueRooms} defaultOption="All Rooms" />
            <SearchInput label="Search Register No" value={searchRegister} onChange={setSearchRegister} placeholder="e.g. 12345" />

            <div className="flex items-center space-x-3 ml-auto mt-2">
              <button onClick={clearFilters} className="flex items-center px-4 py-2 bg-gray-100 text-gray-700 rounded-xl hover:bg-gray-200 transition-colors text-sm font-medium">
                <X className="w-4 h-4 mr-1.5"/> Clear
              </button>
              <button onClick={fetchData} className="flex items-center px-4 py-2 bg-[#1e3a8a] text-white rounded-xl hover:bg-[#1e40af] shadow-md shadow-blue-900/20 transition-colors text-sm font-medium">
                <RefreshCw className="w-4 h-4 mr-1.5" /> Refresh
              </button>
            </div>
          </div>
        </div>

        {loading ? (
          <div className="p-12 text-center text-gray-500 flex flex-col items-center">
            <RefreshCw className="w-8 h-8 animate-spin mb-4 text-blue-500" />
            <p>Loading students...</p>
          </div>
        ) : filteredStudents.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <div className="bg-gray-50 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
              <Users className="w-6 h-6 text-gray-400" />
            </div>
            <p>No students found.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse whitespace-nowrap">
              <thead>
                <tr className="bg-white text-gray-500 text-xs font-semibold uppercase tracking-wider border-b border-gray-100">
                  <th className="py-4 px-5">S.No.</th>
                  <th className="py-4 px-5">Reg No</th>
                  <th className="py-4 px-5">Name</th>
                  <th className="py-4 px-5">Contact</th>
                  <th className="py-4 px-5">Parents Info</th>
                  <th className="py-4 px-5">Accommodation</th>
                  <th className="py-4 px-5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {filteredStudents.map((student, idx) => (
                  <tr key={student.db_id} className="hover:bg-blue-50/40 transition-colors group">
                    <td className="py-4 px-5 text-sm text-gray-500">{idx + 1}</td>
                    <td className="py-4 px-5 font-semibold text-gray-900">{student.studentId || '-'}</td>
                    <td className="py-4 px-5 text-sm text-gray-800">{student.name}</td>
                    <td className="py-4 px-5">
                      <div className="flex flex-col">
                        <span className="text-sm font-medium text-gray-800">{student.phone_number || '-'}</span>
                        <span className="text-xs text-gray-500">{student.email || '-'}</span>
                      </div>
                    </td>
                    <td className="py-4 px-5">
                      <div className="flex flex-col">
                        <span className="text-sm text-gray-700"><span className="text-gray-400 text-xs mr-1">M:</span>{student.mother_phone_number || '-'}</span>
                        <span className="text-sm text-gray-700"><span className="text-gray-400 text-xs mr-1">F:</span>{student.father_phone_number || '-'}</span>
                      </div>
                    </td>
                    <td className="py-4 px-5">
                      <div className="flex flex-col">
                        <span className="text-sm font-medium text-gray-800">{student.hostel_name || 'Unassigned'}</span>
                        <span className="text-xs text-gray-500">Block {student.block_name || '-'} • Room {student.room_name || '-'}</span>
                      </div>
                    </td>
                    <td className="py-4 px-5 text-right">
                      <div className="flex justify-end space-x-2">
                        <button onClick={() => handleEdit(student)} className="p-2 text-gray-400 hover:text-[#1e3a8a] hover:bg-blue-50 rounded-lg transition-colors">
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button onClick={() => handleDelete(student.db_id)} className="p-2 text-gray-400 hover:text-red-600 hover:bg-blue-50 rounded-lg transition-colors">
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

function Wardens() {
  const [wardens, setWardens] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isAdding, setIsAdding] = useState(false);
  const [editingEmail, setEditingEmail] = useState(null);
  const [formData, setFormData] = useState({
    name: '', email: '', password: '', hostel_name: '', block_name: '', floor_number: ''
  });

  const fetchWardens = () => {
    setLoading(true);
    axios.get(`${API_BASE}/admin/wardens`)
      .then(res => {
        setWardens(res.data);
        setLoading(false);
      })
      .catch(err => {
        console.error('Error fetching wardens:', err);
        setLoading(false);
      });
  };

  useEffect(() => {
    fetchWardens();
  }, []);

  const handleCreateOrUpdate = async (e) => {
    e.preventDefault();
    try {
      if (editingEmail) {
        await axios.put(`${API_BASE}/admin/wardens/${editingEmail}`, formData);
        toast.success('Warden updated successfully');
      } else {
        await axios.post(`${API_BASE}/register`, formData);
        toast.success('Warden created successfully');
      }
      resetForm();
      fetchWardens();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Error saving warden');
    }
  };

  const handleEdit = (warden) => {
    setFormData({ ...warden, password: '' });
    setEditingEmail(warden.email);
    setIsAdding(true);
  };

  const handleDelete = async (email) => {
    confirmAction('Are you sure you want to delete this warden and ALL associated student data? This action cannot be undone.', async () => {
      try {
        await axios.delete(`${API_BASE}/admin/wardens/${email}`);
        toast.success('Warden deleted successfully');
        fetchWardens();
      } catch (err) {
        toast.error(err.response?.data?.error || 'Error deleting warden');
      }
    });
  };

  const resetForm = () => {
    setFormData({ name: '', email: '', password: '', hostel_name: '', block_name: '', floor_number: '' });
    setIsAdding(false);
    setEditingEmail(null);
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-gray-900 tracking-tight">Registered Wardens</h2>
        <button 
          onClick={() => {
            if (isAdding) resetForm();
            else setIsAdding(true);
          }} 
          className="bg-[#1e3a8a] text-white px-4 py-2 rounded-xl text-sm font-medium hover:bg-[#1e40af] shadow-sm shadow-blue-900/20 transition-colors"
        >
          {isAdding ? 'Cancel' : '+ Add Warden'}
        </button>
      </div>

      {isAdding && (
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-800 mb-4">{editingEmail ? 'Edit Warden' : 'Create New Warden'}</h3>
          <form onSubmit={handleCreateOrUpdate} className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Name</label>
              <input required type="text" className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a]" value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Email</label>
              <input required type="email" disabled={!!editingEmail} className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a] disabled:bg-gray-100 disabled:text-gray-500" value={formData.email} onChange={e => setFormData({...formData, email: e.target.value})} />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">{editingEmail ? 'New Password (Optional)' : 'Password'}</label>
              <input required={!editingEmail} type="text" className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a]" value={formData.password} onChange={e => setFormData({...formData, password: e.target.value})} />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Hostel Name</label>
              <select className="w-full bg-white border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a] appearance-none cursor-pointer" value={formData.hostel_name} onChange={e => setFormData({...formData, hostel_name: e.target.value})}>
                <option value="">Select Hostel</option>
                {["MH1-Nelson Mandela", "MH2-Bhagat Singh", "MH3-Radha Krishna", "MH7", "PG-Bharati Mens hostel", "LH1", "LH2", "LH3", "LH4"].map(h => (
                  <option key={h} value={h}>{h}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Block Name</label>
              <input type="text" className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a]" value={formData.block_name} onChange={e => setFormData({...formData, block_name: e.target.value})} />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Floor Number</label>
              <input type="text" className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a]" value={formData.floor_number} onChange={e => setFormData({...formData, floor_number: e.target.value})} />
            </div>
            <div className="col-span-full mt-2">
              <button type="submit" className="bg-[#1e3a8a] text-white px-5 py-2 rounded-xl text-sm font-medium hover:bg-[#1e40af]">Save Warden</button>
            </div>
          </form>
        </div>
      )}
      
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex flex-col items-center">
            <RefreshCw className="w-8 h-8 animate-spin mb-4 text-blue-500" />
            <p>Loading wardens...</p>
          </div>
        ) : wardens.length === 0 ? (
          <div className="p-12 text-center text-gray-500">No wardens found.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse whitespace-nowrap">
              <thead>
                <tr className="bg-white text-gray-500 text-xs font-semibold uppercase tracking-wider border-b border-gray-100">
                  <th className="py-4 px-5">Name</th>
                  <th className="py-4 px-5">Email</th>
                  <th className="py-4 px-5">Hostel</th>
                  <th className="py-4 px-5">Block</th>
                  <th className="py-4 px-5">Floor</th>
                  <th className="py-4 px-5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {wardens.map((warden, idx) => (
                  <tr key={idx} className="hover:bg-blue-50/40 transition-colors group">
                    <td className="py-4 px-5 font-medium text-gray-900">
                      <div className="flex items-center">
                        <div className="w-8 h-8 bg-blue-100 text-[#1e3a8a] rounded-full flex items-center justify-center mr-3 font-bold text-xs uppercase">
                          {(warden.name || 'W')[0]}
                        </div>
                        {warden.name || 'Unknown'}
                      </div>
                    </td>
                    <td className="py-4 px-5 text-sm text-gray-600">{warden.email}</td>
                    <td className="py-4 px-5 text-sm font-medium text-gray-800">{warden.hostel_name || '-'}</td>
                    <td className="py-4 px-5 text-sm text-gray-600">{warden.block_name || '-'}</td>
                    <td className="py-4 px-5 text-sm text-gray-600">{warden.floor_number || '-'}</td>
                    <td className="py-4 px-5 text-right">
                      <div className="flex justify-end space-x-2">
                        <button onClick={() => handleEdit(warden)} className="p-2 text-gray-400 hover:text-[#1e3a8a] hover:bg-blue-50 rounded-lg transition-colors">
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button onClick={() => handleDelete(warden.email)} className="p-2 text-gray-400 hover:text-red-600 hover:bg-blue-50 rounded-lg transition-colors">
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

function Sidebar({ onLogout, user }) {
  const location = useLocation();
  
  const navItems = [
    { path: '/', label: 'Attendance', icon: LayoutDashboard },
    { path: '/students', label: 'Student Details', icon: GraduationCap },
    { path: '/requests', label: 'Leave & Outings', icon: ClipboardList },
  ];

  if (user?.role === 'super_admin') {
    navItems.push({ path: '/wardens', label: 'Wardens', icon: Users });
    navItems.push({ path: '/hostel-admins', label: 'Hostel Admins', icon: Building });
    navItems.push({ path: '/report', label: 'Report', icon: ClipboardList });
  } else if (user?.role === 'hostel_admin') {
    navItems.push({ path: '/report', label: 'Report', icon: ClipboardList });
  }

  return (
    <div className="w-64 bg-[#0a0f1c] text-white min-h-screen flex flex-col border-r border-gray-800">
      <div className="p-6 border-b border-gray-800/50">
        <h1 className="text-xl font-bold tracking-widest text-white flex items-center">
          <div className="w-8 h-8 bg-[#1e3a8a] rounded-lg flex items-center justify-center mr-3 shadow-lg shadow-blue-900/20">
            <Building className="w-5 h-5 text-white" />
          </div>
          KARE HOSTELS
        </h1>
        <p className="text-gray-400 text-xs mt-2 font-medium tracking-wider pl-11">MANAGEMENT SYSTEM</p>
      </div>
      
      <div className="px-4 py-6">
        <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-4 px-2">Menu</p>
        <nav className="space-y-1">
          {navItems.map((item) => {
            const active = location.pathname === item.path;
            const Icon = item.icon;
            return (
              <Link 
                key={item.path}
                to={item.path} 
                className={`flex items-center px-4 py-3 rounded-xl transition-all duration-200 group ${
                  active 
                    ? "bg-[#1e3a8a]/10 text-blue-400 font-medium" 
                    : "text-gray-400 hover:bg-white/5 hover:text-gray-200"
                }`}
              >
                <Icon className={`w-5 h-5 mr-3 transition-colors ${active ? "text-blue-500" : "text-gray-500 group-hover:text-gray-300"}`} />
                {item.label}
              </Link>
            );
          })}
        </nav>
      </div>
      
      <div className="mt-auto p-4 border-t border-gray-800/50">
        <button onClick={onLogout} className="flex items-center px-4 py-3 text-gray-400 hover:text-white hover:bg-white/5 rounded-xl transition-all w-full group">
          <LogOut className="w-5 h-5 mr-3 text-gray-500 group-hover:text-gray-300" />
          <span className="font-medium">Logout</span>
        </button>
      </div>
    </div>
  );
}

function HostelAdmins() {
  const [admins, setAdmins] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isAdding, setIsAdding] = useState(false);
  const [editingEmail, setEditingEmail] = useState(null);
  const [formData, setFormData] = useState({
    email: '', password: '', hostel_name: ''
  });

  const fetchAdmins = () => {
    setLoading(true);
    axios.get(`${API_BASE}/admin/hostel_admins`)
      .then(res => {
        setAdmins(res.data);
        setLoading(false);
      })
      .catch(err => {
        toast.error('Error fetching hostel admins');
        setLoading(false);
      });
  };

  useEffect(() => {
    fetchAdmins();
  }, []);

  const handleCreateOrUpdate = async (e) => {
    e.preventDefault();
    try {
      if (editingEmail) {
        await axios.put(`${API_BASE}/admin/hostel_admins/${editingEmail}`, formData);
        toast.success('Hostel Admin updated successfully');
      } else {
        await axios.post(`${API_BASE}/admin/hostel_admins`, formData);
        toast.success('Hostel Admin created successfully');
      }
      resetForm();
      fetchAdmins();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Error saving hostel admin');
    }
  };

  const handleEdit = (admin) => {
    setFormData({ ...admin, password: '' });
    setEditingEmail(admin.email);
    setIsAdding(true);
  };

  const handleDelete = async (email) => {
    confirmAction('Are you sure you want to delete this hostel admin?', async () => {
      try {
        await axios.delete(`${API_BASE}/admin/hostel_admins/${email}`);
        toast.success('Hostel Admin deleted successfully');
        fetchAdmins();
      } catch (err) {
        toast.error('Error deleting hostel admin');
      }
    });
  };

  const resetForm = () => {
    setFormData({ email: '', password: '', hostel_name: '' });
    setEditingEmail(null);
    setIsAdding(false);
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-gray-900 tracking-tight">Manage Hostel Admins</h2>
        {!isAdding && (
          <button onClick={() => setIsAdding(true)} className="bg-[#1e3a8a] text-white px-5 py-2.5 rounded-xl font-semibold hover:bg-[#1e40af] shadow-md shadow-blue-900/20 transition-colors">
            + Add Hostel Admin
          </button>
        )}
      </div>

      {isAdding && (
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-800 mb-4">{editingEmail ? 'Edit Hostel Admin' : 'New Hostel Admin'}</h3>
          <form onSubmit={handleCreateOrUpdate} className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Email</label>
              <input type="email" required disabled={!!editingEmail} className={`w-full border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a] ${editingEmail ? 'bg-gray-50 text-gray-400' : ''}`} value={formData.email} onChange={e => setFormData({...formData, email: e.target.value})} />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Password {editingEmail && <span className="text-gray-400 font-normal">(Leave blank to keep current)</span>}</label>
              <input type="password" required={!editingEmail} className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a]" value={formData.password} onChange={e => setFormData({...formData, password: e.target.value})} />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-500 mb-1">Hostel Name</label>
              <select required className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#1e3a8a]" value={formData.hostel_name} onChange={e => setFormData({...formData, hostel_name: e.target.value})}>
                <option value="">Select Hostel</option>
                {FIXED_HOSTELS.map(h => <option key={h} value={h}>{h}</option>)}
              </select>
            </div>
            <div className="col-span-full mt-2 flex space-x-3">
              <button type="submit" className="bg-[#1e3a8a] text-white px-5 py-2 rounded-xl text-sm font-medium hover:bg-[#1e40af]">Save</button>
              <button type="button" onClick={resetForm} className="bg-gray-100 text-gray-700 px-5 py-2 rounded-xl text-sm font-medium hover:bg-gray-200">Cancel</button>
            </div>
          </form>
        </div>
      )}

      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex flex-col items-center">
            <RefreshCw className="w-8 h-8 animate-spin mb-4 text-blue-500" />
            <p>Loading hostel admins...</p>
          </div>
        ) : admins.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <div className="bg-gray-50 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
              <Building className="w-6 h-6 text-gray-400" />
            </div>
            <p>No hostel admins created yet.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse whitespace-nowrap">
              <thead>
                <tr className="bg-white text-gray-500 text-xs font-semibold uppercase tracking-wider border-b border-gray-100">
                  <th className="py-4 px-5">S.No.</th>
                  <th className="py-4 px-5">Email</th>
                  <th className="py-4 px-5">Hostel Name</th>
                  <th className="py-4 px-5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {admins.map((admin, idx) => (
                  <tr key={admin.email} className="hover:bg-blue-50/40 transition-colors group">
                    <td className="py-4 px-5 text-sm text-gray-500">{idx + 1}</td>
                    <td className="py-4 px-5 font-semibold text-gray-900">{admin.email}</td>
                    <td className="py-4 px-5 text-sm text-gray-700">
                      <span className="inline-flex items-center px-2.5 py-1 rounded-md bg-purple-50 text-purple-700 font-medium">
                        {admin.hostel_name}
                      </span>
                    </td>
                    <td className="py-4 px-5 text-right">
                      <div className="flex justify-end space-x-2">
                        <button onClick={() => handleEdit(admin)} className="p-2 text-gray-400 hover:text-[#1e3a8a] hover:bg-blue-50 rounded-lg transition-colors">
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button onClick={() => handleDelete(admin.email)} className="p-2 text-gray-400 hover:text-red-600 hover:bg-blue-50 rounded-lg transition-colors">
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

function Login({ onLogin }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const handleLogin = async (e) => {
    e.preventDefault();
    try {
      const res = await axios.post(`${API_BASE}/admin/login`, { email, password });
      if (res.data.success) {
        localStorage.setItem('admin_auth', JSON.stringify(res.data));
        onLogin(res.data);
      }
    } catch (err) {
      setError('Invalid email or password');
    }
  };

  return (
    <div className="min-h-screen bg-[#0a0f1c] flex items-center justify-center p-4 font-sans">
      <div className="bg-white rounded-3xl shadow-2xl w-full max-w-md p-10 relative overflow-hidden border border-gray-100">
        <div className="absolute top-0 left-0 w-full h-2 bg-[#1e3a8a]"></div>
        
        <div className="text-center mb-10 mt-4">
          <img src="https://upload.wikimedia.org/wikipedia/en/5/53/Kalasalingam_Academy_of_Research_and_Education_logo.png" alt="KARE Logo" className="h-20 mx-auto mb-6 object-contain" />
          <h1 className="text-3xl font-extrabold text-gray-900 tracking-tight">KARE HOSTELS</h1>
          <p className="text-gray-500 text-sm mt-3 font-medium">Log in to your account</p>
        </div>

        {error && (
          <div className="bg-blue-50 text-red-600 p-4 rounded-xl text-sm font-semibold mb-6 flex items-center justify-center border border-red-100">
            {error}
          </div>
        )}

        <form onSubmit={handleLogin} className="space-y-6">
          <div>
            <label className="block text-xs font-bold text-gray-600 uppercase tracking-wider mb-2">Email Address</label>
            <input 
              type="email" 
              className="w-full bg-gray-50 border border-gray-200 text-gray-900 rounded-xl px-4 py-3.5 outline-none focus:bg-white focus:ring-2 focus:ring-[#1e3a8a] transition-all font-medium" 
              value={email} 
              onChange={e => setEmail(e.target.value)}
              placeholder="admin@klu.ac.in"
              required
            />
          </div>
          <div>
            <label className="block text-xs font-bold text-gray-600 uppercase tracking-wider mb-2">Password</label>
            <input 
              type="password" 
              className="w-full bg-gray-50 border border-gray-200 text-gray-900 rounded-xl px-4 py-3.5 outline-none focus:bg-white focus:ring-2 focus:ring-[#1e3a8a] transition-all font-medium" 
              value={password} 
              onChange={e => setPassword(e.target.value)}
              placeholder="••••••••"
              required
            />
          </div>
          <button type="submit" className="w-full bg-[#1e3a8a] text-white font-bold py-4 rounded-xl hover:bg-[#1e40af] transition-colors shadow-lg shadow-blue-900/20 mt-4 text-sm tracking-wide uppercase">
            Log In
          </button>
        </form>
      </div>
    </div>
  );
}

function App() {
  const [user, setUser] = useState(() => {
    const auth = localStorage.getItem('admin_auth');
    if (auth === 'true') return { role: 'super_admin' };
    if (auth) {
      try { return JSON.parse(auth); } catch(e) { return null; }
    }
    return null;
  });

  const handleLogout = () => {
    localStorage.removeItem('admin_auth');
    setUser(null);
  };

  if (!user) {
    return (
      <>
        <Toaster />
        <Login onLogin={(u) => setUser(u)} />
      </>
    );
  }

  return (
    <>
      <Toaster />
      <Router>
      <div className="flex bg-[#f8fafc] min-h-screen font-sans">
        <Sidebar onLogout={handleLogout} user={user} />
        
        <div className="flex-1 flex flex-col min-w-0 h-screen overflow-hidden">
          <header className="bg-white border-b border-gray-100 px-8 py-5 flex justify-between items-center z-10 sticky top-0 shadow-sm">
            <h2 className="text-lg font-bold text-gray-800 tracking-tight">{user.role === 'super_admin' ? 'Central Administration' : `Hostel Management - ${user.hostel_name}`}</h2>
            <div className="flex items-center space-x-4">
              <div className="flex items-center space-x-3 bg-gray-50 px-3 py-1.5 rounded-full border border-gray-100">
                <div className="w-8 h-8 bg-[#1e3a8a] rounded-full flex items-center justify-center text-white font-bold shadow-sm shadow-blue-900/20">
                  {user.role === 'super_admin' ? 'SA' : 'HA'}
                </div>
                <span className="text-sm font-semibold text-gray-700 pr-2">{user.role === 'super_admin' ? 'System Admin' : user.hostel_name}</span>
              </div>
            </div>
          </header>
          
          <main className="p-8 flex-1 overflow-y-auto">
            <div className="max-w-7xl mx-auto">
              <Routes>
                <Route path="/" element={<Dashboard user={user} />} />
                <Route path="/students" element={<StudentDetails user={user} />} />
                <Route path="/requests" element={<LeavesAndOutings user={user} />} />
                <Route path="/report" element={<Report user={user} />} />
                {user.role === 'super_admin' && (
                  <>
                    <Route path="/wardens" element={<Wardens />} />
                    <Route path="/hostel-admins" element={<HostelAdmins />} />
                  </>
                )}
              </Routes>
            </div>
          </main>
        </div>
      </div>
    </Router>
    </>
  );
}

export default App;
