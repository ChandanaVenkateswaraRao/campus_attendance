import React, { useState, useEffect } from 'react';
import axios from 'axios';
import toast from 'react-hot-toast';
import { FileText, Clock, CheckCircle2, XCircle, Search } from 'lucide-react';

const API_BASE = 'http://localhost:3000/api';

export default function LeavesAndOutings({ user }) {
  const [leaves, setLeaves] = useState([]);
  const [outings, setOutings] = useState([]);
  const [activeTab, setActiveTab] = useState('leaves');
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [leavesRes, outingsRes] = await Promise.all([
        axios.get(`${API_BASE}/admin/leaves`),
        axios.get(`${API_BASE}/admin/outings`)
      ]);
      setLeaves(leavesRes.data || []);
      setOutings(outingsRes.data || []);
    } catch (err) {
      toast.error('Failed to load requests');
    } finally {
      setLoading(false);
    }
  };

  const updateStatus = async (type, id, status) => {
    try {
      await axios.put(`${API_BASE}/admin/${type}/${id}/status`, { status });
      toast.success(`Request ${status}`);
      fetchData();
    } catch (err) {
      toast.error('Failed to update status');
    }
  };

  const renderTable = (type) => {
    let data = type === 'leaves' ? leaves : outings;
    
    // Filter by hostel_admin's hostel if not super_admin
    if (user?.role === 'hostel_admin' && user?.hostel_name) {
      data = data.filter(item => item.hostel_name === user.hostel_name);
    }
    
    if (search) {
      const s = search.toLowerCase();
      data = data.filter(item => 
        (item.student_name && item.student_name.toLowerCase().includes(s)) ||
        (item.register_number && item.register_number.toLowerCase().includes(s))
      );
    }

    return (
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-gray-50 border-b border-gray-100 text-xs uppercase tracking-wider text-gray-500">
                <th className="p-4 font-semibold">Student</th>
                {user?.role === 'super_admin' && <th className="p-4 font-semibold">Hostel / Block</th>}
                <th className="p-4 font-semibold">Room / Floor</th>
                <th className="p-4 font-semibold">Dates & Time</th>
                <th className="p-4 font-semibold">Reason</th>
                <th className="p-4 font-semibold">Status</th>
                <th className="p-4 font-semibold text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {data.map((item) => (
                <tr key={item.id} className="hover:bg-gray-50/50 transition-colors">
                  <td className="p-4">
                    <p className="font-semibold text-sm text-gray-900">{item.student_name || 'N/A'}</p>
                    <p className="text-xs text-gray-500">{item.register_number || 'N/A'}</p>
                  </td>
                  {user?.role === 'super_admin' && (
                    <td className="p-4">
                      <p className="text-sm text-gray-900">{item.hostel_name || 'N/A'}</p>
                      <p className="text-xs text-gray-500">{item.block_name || 'N/A'}</p>
                    </td>
                  )}
                  <td className="p-4">
                    <p className="text-sm font-medium text-gray-900">{item.room_number || 'Unassigned'}</p>
                    <p className="text-xs text-gray-500">Floor: {item.floor_number || 'N/A'}</p>
                  </td>
                  <td className="p-4 text-sm text-gray-600">
                    {type === 'leaves' ? (
                      <div>
                        <div><span className="font-medium">From:</span> {item.from_date?.replace('T', ' ')}</div>
                        <div><span className="font-medium">To:</span> {item.to_date?.replace('T', ' ')}</div>
                      </div>
                    ) : (
                      <div>
                        <div><span className="font-medium">Date:</span> {item.date}</div>
                        <div><span className="font-medium">Time:</span> {item.start_time} - {item.end_time}</div>
                      </div>
                    )}
                  </td>
                  <td className="p-4 text-sm text-gray-600 max-w-[200px] truncate" title={item.reason}>
                    {item.reason || '-'}
                  </td>
                  <td className="p-4">
                    <span className={`px-2 py-1 text-xs font-bold rounded-lg uppercase tracking-wider ${
                      item.status === 'APPROVED' ? 'bg-green-100 text-green-700' :
                      item.status === 'REJECTED' ? 'bg-red-100 text-red-700' :
                      'bg-amber-100 text-amber-700'
                    }`}>
                      {item.status}
                    </span>
                  </td>
                  <td className="p-4 text-right">
                    <div className="flex justify-end space-x-2">
                      {item.status === 'PENDING' && (
                        <>
                          <button 
                            onClick={() => updateStatus(type, item.id, 'APPROVED')}
                            className="p-1.5 text-green-600 hover:bg-green-50 rounded-lg transition-colors"
                            title="Approve"
                          >
                            <CheckCircle2 className="w-5 h-5" />
                          </button>
                          <button 
                            onClick={() => updateStatus(type, item.id, 'REJECTED')}
                            className="p-1.5 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                            title="Reject"
                          >
                            <XCircle className="w-5 h-5" />
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
              {data.length === 0 && (
                <tr>
                  <td colSpan={user?.role === 'super_admin' ? 7 : 6} className="p-8 text-center text-gray-500">
                    No {type} requests found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    );
  };

  return (
    <div className="p-8">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-8 gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Requests</h1>
          <p className="text-sm text-gray-500 mt-1">Manage student leave and outing permissions.</p>
        </div>
        
        <div className="w-full md:w-64">
          <div className="relative">
            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input 
              type="text" 
              placeholder="Search student..."
              className="w-full bg-white border border-gray-200 text-gray-800 rounded-xl pl-9 pr-4 py-2 text-sm focus:ring-2 focus:ring-[#1e3a8a] outline-none shadow-sm"
              value={search}
              onChange={e => setSearch(e.target.value)}
            />
          </div>
        </div>
      </div>

      <div className="flex space-x-2 mb-6">
        <button 
          onClick={() => setActiveTab('leaves')}
          className={`flex items-center px-4 py-2 rounded-lg font-medium transition-colors ${activeTab === 'leaves' ? 'bg-[#1e3a8a] text-white shadow-md' : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50'}`}
        >
          <FileText className="w-4 h-4 mr-2" /> Leaves
        </button>
        <button 
          onClick={() => setActiveTab('outings')}
          className={`flex items-center px-4 py-2 rounded-lg font-medium transition-colors ${activeTab === 'outings' ? 'bg-[#1e3a8a] text-white shadow-md' : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50'}`}
        >
          <Clock className="w-4 h-4 mr-2" /> Outings
        </button>
      </div>

      {loading ? (
        <div className="text-center py-12 text-gray-500">Loading requests...</div>
      ) : (
        renderTable(activeTab)
      )}
    </div>
  );
}
