"use client";

import { useState, useEffect } from 'react';
import axios from 'axios';
import { LogOut, Calendar, Clock, CheckCircle2, User, FileText, ArrowRight } from 'lucide-react';
import { format, addHours, parseISO } from 'date-fns';
import { GoogleOAuthProvider, GoogleLogin } from '@react-oauth/google';
import { jwtDecode } from "jwt-decode";

const API_BASE = 'http://localhost:3000/api';
// Replace this with your actual Google Client ID, or put it in .env.local as NEXT_PUBLIC_GOOGLE_CLIENT_ID
const GOOGLE_CLIENT_ID = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID || '914993965383-2tsc34l4hghdn1kbrr9tfsrcif956v8i.apps.googleusercontent.com';

export default function StudentPortal() {
  const [user, setUser] = useState<{ email: string; token: string; name: string; studentId: string } | null>(null);
  
  // Login State
  const [loginError, setLoginError] = useState('');
  const [isLoggingIn, setIsLoggingIn] = useState(false);

  // Dashboard Data
  const [attendanceList, setAttendanceList] = useState<{date: string, status: string}[]>([]);
  const [leaves, setLeaves] = useState<any[]>([]);
  const [outings, setOutings] = useState<any[]>([]);

  // Forms
  const [activeTab, setActiveTab] = useState<'attendance' | 'leave' | 'outing'>('attendance');

  const [leaveForm, setLeaveForm] = useState({
    fromDate: '',
    fromTime: '',
    toDate: '',
    toTime: '',
    reason: ''
  });

  const [outingForm, setOutingForm] = useState({
    startTime: '',
    reason: ''
  });

  const [formMessage, setFormMessage] = useState({ type: '', text: '' });

  useEffect(() => {
    const savedUser = localStorage.getItem('student_user');
    if (savedUser) {
      setUser(JSON.parse(savedUser));
    }
  }, []);

  useEffect(() => {
    if (user) {
      fetchDashboardData();
    }
  }, [user]);

  const fetchDashboardData = async () => {
    try {
      const headers = { Authorization: `Bearer ${user?.token}` };
      const [attRes, leavesRes, outingsRes] = await Promise.all([
        axios.get(`${API_BASE}/student/attendance`, { headers }),
        axios.get(`${API_BASE}/student/leaves`, { headers }),
        axios.get(`${API_BASE}/student/outings`, { headers })
      ]);
      setAttendanceList(attRes.data.attendanceList || []);
      setLeaves(leavesRes.data || []);
      setOutings(outingsRes.data || []);
    } catch (err) {
      console.error('Error fetching data', err);
    }
  };

  const handleGoogleSuccess = async (credentialResponse: any) => {
    if (!credentialResponse.credential) {
      setLoginError('Google login failed: No credential received');
      return;
    }
    
    setIsLoggingIn(true);
    setLoginError('');
    
    try {
      // Decode the JWT to get the user's email
      const decoded: any = jwtDecode(credentialResponse.credential);
      const email = decoded.email;
      
      if (!email) {
        setLoginError('Could not get email from Google Login.');
        setIsLoggingIn(false);
        return;
      }

      // Send the email to our backend to authenticate as a registered student
      const res = await axios.post(`${API_BASE}/student/login`, { email: email });
      
      const userData = {
        email: res.data.student.email,
        token: res.data.token,
        name: res.data.student.name,
        studentId: res.data.student.studentId
      };
      
      setUser(userData);
      localStorage.setItem('student_user', JSON.stringify(userData));
    } catch (err: any) {
      setLoginError(err.response?.data?.error || 'Login failed. Please ensure the warden registered your Google email.');
    } finally {
      setIsLoggingIn(false);
    }
  };

  const handleLogout = () => {
    setUser(null);
    localStorage.removeItem('student_user');
  };

  const submitLeave = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormMessage({ type: '', text: '' });
    
    if (!leaveForm.fromDate || !leaveForm.fromTime || !leaveForm.toDate || !leaveForm.toTime || !leaveForm.reason.trim()) {
      setFormMessage({ type: 'error', text: 'Please fill all fields' });
      return;
    }

    try {
      const from_date = `${leaveForm.fromDate}T${leaveForm.fromTime}`;
      const to_date = `${leaveForm.toDate}T${leaveForm.toTime}`;
      
      await axios.post(`${API_BASE}/student/leave`, { from_date, to_date, reason: leaveForm.reason }, {
        headers: { Authorization: `Bearer ${user?.token}` }
      });
      setFormMessage({ type: 'success', text: 'Leave applied successfully' });
      setLeaveForm({ fromDate: '', fromTime: '', toDate: '', toTime: '', reason: '' });
      fetchDashboardData();
    } catch (err: any) {
      setFormMessage({ type: 'error', text: err.response?.data?.error || 'Failed to apply leave' });
    }
  };

  const submitOuting = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormMessage({ type: '', text: '' });
    
    if (!outingForm.startTime || !outingForm.reason.trim()) {
      setFormMessage({ type: 'error', text: 'Please fill all fields' });
      return;
    }

    try {
      const today = format(new Date(), 'yyyy-MM-dd');
      
      // Calculate end time (6 hours from start)
      const startDateTime = new Date(`${today}T${outingForm.startTime}`);
      const endDateTime = addHours(startDateTime, 6);
      const end_time = format(endDateTime, 'HH:mm');

      await axios.post(`${API_BASE}/student/outing`, { 
        date: today, 
        start_time: outingForm.startTime, 
        end_time,
        reason: outingForm.reason
      }, {
        headers: { Authorization: `Bearer ${user?.token}` }
      });
      
      setFormMessage({ type: 'success', text: 'Outing applied successfully' });
      setOutingForm({ startTime: '', reason: '' });
      fetchDashboardData();
    } catch (err: any) {
      setFormMessage({ type: 'error', text: err.response?.data?.error || 'Failed to apply outing' });
    }
  };

  // ---------------- LOGIN VIEW ----------------
  if (!user) {
    return (
      <GoogleOAuthProvider clientId={GOOGLE_CLIENT_ID}>
        <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-md overflow-hidden">
            <div className="bg-blue-600 p-8 text-center">
              <div className="w-16 h-16 bg-white rounded-full flex items-center justify-center mx-auto mb-4 shadow-lg">
                <User className="w-8 h-8 text-blue-600" />
              </div>
              <h1 className="text-2xl font-bold text-white">Student Portal</h1>
              <p className="text-blue-100 mt-2 text-sm">Sign in with your Google account</p>
            </div>
            
            <div className="p-8 flex flex-col items-center">
              {loginError && (
                <div className="mb-6 w-full p-3 bg-red-50 text-red-600 rounded-lg text-sm font-medium border border-red-100 text-center">
                  {loginError}
                </div>
              )}
              
              <div className="mb-4 text-sm text-gray-600 text-center">
                Please sign in using the Google email you provided during registration.
              </div>

              {isLoggingIn ? (
                <div className="py-4 text-blue-600 font-medium animate-pulse">Verifying student details...</div>
              ) : (
                <div className="w-full flex justify-center mt-2">
                  <GoogleLogin
                    onSuccess={handleGoogleSuccess}
                    onError={() => setLoginError('Google Login failed. Please try again.')}
                    theme="filled_blue"
                    size="large"
                    shape="pill"
                    text="continue_with"
                  />
                </div>
              )}
            </div>
          </div>
        </div>
      </GoogleOAuthProvider>
    );
  }

  // ---------------- DASHBOARD VIEW ----------------
  return (
    <div className="min-h-screen bg-gray-50 text-gray-900">
      {/* Navbar */}
      <nav className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center mr-3">
                <User className="w-5 h-5 text-white" />
              </div>
              <span className="font-bold text-xl tracking-tight text-gray-900">Student Portal</span>
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-right hidden sm:block">
                <p className="text-sm font-semibold text-gray-900">{user.name}</p>
                <p className="text-xs text-gray-500">{user.studentId}</p>
              </div>
              <button 
                onClick={handleLogout} 
                className="p-2 text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-xl transition-colors"
                title="Logout"
              >
                <LogOut className="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>
      </nav>

      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        
        {/* Welcome Card */}
        <div className="bg-gradient-to-r from-blue-600 to-indigo-700 rounded-3xl p-8 text-white mb-8 shadow-lg shadow-blue-900/20">
          <h2 className="text-3xl font-bold mb-2">Hello, {user.name}! 👋</h2>
          <p className="text-blue-100 opacity-90">Manage your attendance, apply for leaves, and request outings all in one place.</p>
        </div>

        {/* Tab Navigation */}
        <div className="flex space-x-2 mb-6 overflow-x-auto pb-2">
          <button 
            onClick={() => setActiveTab('attendance')}
            className={`flex items-center px-5 py-2.5 rounded-xl font-medium transition-colors whitespace-nowrap ${activeTab === 'attendance' ? 'bg-white text-blue-600 shadow-sm border border-gray-200' : 'text-gray-500 hover:bg-gray-100 hover:text-gray-900'}`}
          >
            <CheckCircle2 className="w-4 h-4 mr-2" /> My Attendance
          </button>
          <button 
            onClick={() => setActiveTab('leave')}
            className={`flex items-center px-5 py-2.5 rounded-xl font-medium transition-colors whitespace-nowrap ${activeTab === 'leave' ? 'bg-white text-blue-600 shadow-sm border border-gray-200' : 'text-gray-500 hover:bg-gray-100 hover:text-gray-900'}`}
          >
            <Calendar className="w-4 h-4 mr-2" /> Apply Leave
          </button>
          <button 
            onClick={() => setActiveTab('outing')}
            className={`flex items-center px-5 py-2.5 rounded-xl font-medium transition-colors whitespace-nowrap ${activeTab === 'outing' ? 'bg-white text-blue-600 shadow-sm border border-gray-200' : 'text-gray-500 hover:bg-gray-100 hover:text-gray-900'}`}
          >
            <Clock className="w-4 h-4 mr-2" /> Request Outing
          </button>
        </div>

        {/* Form Messages */}
        {formMessage.text && (
          <div className={`mb-6 p-4 rounded-xl text-sm font-medium border flex items-center ${formMessage.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
            {formMessage.text}
          </div>
        )}

        {/* Content Area */}
        <div className="bg-white rounded-3xl shadow-sm border border-gray-100 overflow-hidden">
          
          {/* Attendance Tab */}
          {activeTab === 'attendance' && (
            <div className="p-8">
              <h3 className="text-lg font-bold text-gray-900 mb-6 flex items-center">
                <CheckCircle2 className="w-5 h-5 mr-2 text-blue-600" /> Recent Attendance
              </h3>
              
              {attendanceList.length === 0 ? (
                <div className="text-center py-12 bg-gray-50 rounded-2xl border border-dashed border-gray-200">
                  <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-3">
                    <CheckCircle2 className="w-6 h-6 text-gray-400" />
                  </div>
                  <p className="text-gray-500 font-medium">No attendance records found yet.</p>
                </div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                  {attendanceList.map((record, idx) => {
                    const dateObj = new Date(record.date);
                    const isPresent = record.status === 'Present';
                    return (
                      <div key={idx} className={`flex items-center p-4 border rounded-2xl ${isPresent ? 'bg-green-50/50 border-green-100' : 'bg-red-50/50 border-red-100'}`}>
                        <div className={`w-10 h-10 rounded-full flex items-center justify-center font-bold mr-4 shrink-0 ${isPresent ? 'bg-green-100 text-green-600' : 'bg-red-100 text-red-600'}`}>
                          {format(dateObj, 'dd')}
                        </div>
                        <div>
                          <p className="text-sm font-semibold text-gray-900">{format(dateObj, 'MMMM yyyy')}</p>
                          <p className={`text-xs font-medium flex items-center mt-0.5 ${isPresent ? 'text-green-600' : 'text-red-600'}`}>
                            <span className={`w-1.5 h-1.5 rounded-full mr-1.5 ${isPresent ? 'bg-green-500' : 'bg-red-500'}`}></span> {record.status}
                          </p>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* Leave Tab */}
          {activeTab === 'leave' && (
            <div className="flex flex-col lg:flex-row">
              <div className="p-8 lg:w-1/2 lg:border-r border-gray-100">
                <h3 className="text-lg font-bold text-gray-900 mb-6 flex items-center">
                  <Calendar className="w-5 h-5 mr-2 text-blue-600" /> Apply for Leave
                </h3>
                
                <form onSubmit={submitLeave} className="space-y-5">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">From Date</label>
                      <input 
                        type="date" 
                        required 
                        className="w-full bg-gray-50 border border-gray-200 text-gray-900 rounded-xl px-4 py-2.5 text-sm focus:ring-2 focus:ring-blue-600 focus:bg-white outline-none transition-all"
                        value={leaveForm.fromDate}
                        onChange={e => setLeaveForm({...leaveForm, fromDate: e.target.value})}
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">Time</label>
                      <input 
                        type="time" 
                        required 
                        className="w-full bg-gray-50 border border-gray-200 text-gray-900 rounded-xl px-4 py-2.5 text-sm focus:ring-2 focus:ring-blue-600 focus:bg-white outline-none transition-all"
                        value={leaveForm.fromTime}
                        onChange={e => setLeaveForm({...leaveForm, fromTime: e.target.value})}
                      />
                    </div>
                  </div>
                  
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">To Date</label>
                      <input 
                        type="date" 
                        required 
                        className="w-full bg-gray-50 border border-gray-200 text-gray-900 rounded-xl px-4 py-2.5 text-sm focus:ring-2 focus:ring-blue-600 focus:bg-white outline-none transition-all"
                        value={leaveForm.toDate}
                        min={leaveForm.fromDate}
                        onChange={e => setLeaveForm({...leaveForm, toDate: e.target.value})}
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">Time</label>
                      <input 
                        type="time" 
                        required 
                        className="w-full bg-gray-50 border border-gray-200 text-gray-900 rounded-xl px-4 py-2.5 text-sm focus:ring-2 focus:ring-blue-600 focus:bg-white outline-none transition-all"
                        value={leaveForm.toTime}
                        onChange={e => setLeaveForm({...leaveForm, toTime: e.target.value})}
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">Reason</label>
                    <textarea 
                      required 
                      rows={3}
                      placeholder="Why are you taking a leave?"
                      className="w-full bg-gray-50 border border-gray-200 text-gray-900 rounded-xl px-4 py-2.5 text-sm focus:ring-2 focus:ring-blue-600 focus:bg-white outline-none transition-all resize-none"
                      value={leaveForm.reason}
                      onChange={e => setLeaveForm({...leaveForm, reason: e.target.value})}
                    />
                  </div>

                  <button type="submit" className="w-full bg-blue-600 text-white font-semibold py-3 rounded-xl hover:bg-blue-700 transition-colors shadow-md shadow-blue-600/20 mt-4">
                    Submit Leave Request
                  </button>
                </form>
              </div>
              
              <div className="p-8 lg:w-1/2 bg-gray-50/50">
                <h3 className="text-lg font-bold text-gray-900 mb-6 flex items-center">
                  <FileText className="w-5 h-5 mr-2 text-gray-400" /> Leave History
                </h3>
                
                {leaves.length === 0 ? (
                  <p className="text-gray-500 text-sm text-center py-8">No leave requests found.</p>
                ) : (
                  <div className="space-y-4">
                    {leaves.map((leave, idx) => (
                      <div key={idx} className="bg-white border border-gray-200 rounded-2xl p-4 shadow-sm flex flex-col justify-between">
                        <div className="flex justify-between items-start mb-2">
                          <div className="flex items-center text-sm font-medium text-gray-900">
                            {format(parseISO(leave.from_date), 'MMM dd, HH:mm')} 
                            <ArrowRight className="w-4 h-4 mx-2 text-gray-400" /> 
                            {format(parseISO(leave.to_date), 'MMM dd, HH:mm')}
                          </div>
                          <span className={`px-2 py-1 text-[10px] font-bold rounded-md uppercase tracking-wider ${
                            leave.status === 'APPROVED' ? 'bg-green-100 text-green-700' :
                            leave.status === 'REJECTED' ? 'bg-red-100 text-red-700' :
                            'bg-amber-100 text-amber-700'
                          }`}>
                            {leave.status}
                          </span>
                        </div>
                        {leave.reason && <p className="text-xs text-gray-500 border-t border-gray-100 pt-2 mt-1">Reason: {leave.reason}</p>}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Outing Tab */}
          {activeTab === 'outing' && (
            <div className="flex flex-col lg:flex-row">
              <div className="p-8 lg:w-1/2 lg:border-r border-gray-100">
                <h3 className="text-lg font-bold text-gray-900 mb-6 flex items-center">
                  <Clock className="w-5 h-5 mr-2 text-blue-600" /> Outing Permission
                </h3>
                
                <form onSubmit={submitOuting} className="space-y-5">
                  <div>
                    <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">Date</label>
                    <input 
                      type="text" 
                      disabled
                      className="w-full bg-gray-100 border border-gray-200 text-gray-600 rounded-xl px-4 py-2.5 text-sm font-medium cursor-not-allowed"
                      value={format(new Date(), 'dd MMM yyyy') + ' (Today)'}
                    />
                  </div>
                  
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">Start Time</label>
                      <input 
                        type="time" 
                        required 
                        className="w-full bg-gray-50 border border-gray-200 text-gray-900 rounded-xl px-4 py-2.5 text-sm focus:ring-2 focus:ring-blue-600 focus:bg-white outline-none transition-all"
                        value={outingForm.startTime}
                        onChange={e => setOutingForm({...outingForm, startTime: e.target.value})}
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">End Time</label>
                      <div className="w-full bg-gray-100 border border-gray-200 text-gray-600 rounded-xl px-4 py-2.5 text-sm font-medium flex items-center">
                        {outingForm.startTime ? format(addHours(new Date(`2000-01-01T${outingForm.startTime}`), 6), 'HH:mm') : '--:--'}
                      </div>
                      <p className="text-[10px] text-gray-500 mt-1">Automatically set to 6 hours later</p>
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1.5">Reason</label>
                    <textarea 
                      required 
                      rows={3}
                      placeholder="Why do you need an outing pass?"
                      className="w-full bg-gray-50 border border-gray-200 text-gray-900 rounded-xl px-4 py-2.5 text-sm focus:ring-2 focus:ring-blue-600 focus:bg-white outline-none transition-all resize-none"
                      value={outingForm.reason}
                      onChange={e => setOutingForm({...outingForm, reason: e.target.value})}
                    />
                  </div>

                  <button type="submit" className="w-full bg-blue-600 text-white font-semibold py-3 rounded-xl hover:bg-blue-700 transition-colors shadow-md shadow-blue-600/20 mt-4">
                    Request Outing Pass
                  </button>
                </form>
              </div>
              
              <div className="p-8 lg:w-1/2 bg-gray-50/50">
                <h3 className="text-lg font-bold text-gray-900 mb-6 flex items-center">
                  <FileText className="w-5 h-5 mr-2 text-gray-400" /> Outing History
                </h3>
                
                {outings.length === 0 ? (
                  <p className="text-gray-500 text-sm text-center py-8">No outing requests found.</p>
                ) : (
                  <div className="space-y-4">
                    {outings.map((outing, idx) => (
                      <div key={idx} className="bg-white border border-gray-200 rounded-2xl p-4 shadow-sm flex flex-col justify-between">
                        <div className="flex justify-between items-start mb-2">
                          <div>
                            <p className="text-xs font-semibold text-gray-500 mb-1">{format(parseISO(outing.date), 'MMM dd, yyyy')}</p>
                            <div className="flex items-center text-sm font-medium text-gray-900">
                              {outing.start_time}
                              <ArrowRight className="w-4 h-4 mx-2 text-gray-400" /> 
                              {outing.end_time}
                            </div>
                          </div>
                          <span className={`px-2 py-1 text-[10px] font-bold rounded-md uppercase tracking-wider ${
                            outing.status === 'APPROVED' ? 'bg-green-100 text-green-700' :
                            outing.status === 'REJECTED' ? 'bg-red-100 text-red-700' :
                            'bg-amber-100 text-amber-700'
                          }`}>
                            {outing.status}
                          </span>
                        </div>
                        {outing.reason && <p className="text-xs text-gray-500 border-t border-gray-100 pt-2 mt-1">Reason: {outing.reason}</p>}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
