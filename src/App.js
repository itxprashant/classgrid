import React from 'react';
import './App.css';
import Navbar from './components/Navbar/Navbar';
import Footer from './components/Footer/Footer';
import Generator from './pages/Generator';

import { Routes, Route, BrowserRouter, Navigate, useLocation, Outlet } from 'react-router-dom';
import EmptyLectureHalls from './pages/EmptyLectureHalls';
import CourseExplorer from './pages/CourseExplorer';
import CourseDetails from './pages/CourseDetails';
import CourseOffering from './pages/CourseOffering';
import CourseRoster from './pages/CourseRoster';
import ProfessorExplorer from './pages/ProfessorExplorer';
import ProfessorDetail from './pages/ProfessorDetail';
import StudentExplorer from './pages/StudentExplorer';
import StudentDetail from './pages/StudentDetail';
import MyCalendar from './pages/MyCalendar';
import RoomSchedules from './pages/RoomSchedules';
import RoomDetail from './pages/RoomDetail';
import Feedback from './pages/Feedback';
import AdminGate from './pages/admin/AdminGate';
import AdminShell from './pages/admin/AdminShell';
import AdminDashboard from './pages/admin/AdminDashboard';
import AdminFeedback from './pages/admin/AdminFeedback';
import AdminReports from './pages/admin/AdminReports';
import { AuthProvider } from './auth/AuthContext';
import { SemesterDataProvider } from './data/SemesterDataContext';
import SemesterDataGate from './data/SemesterDataGate';
import { ThemeProvider } from './theme/ThemeProvider';

function RootRedirect() {
    const { search } = useLocation();
    const params = new URLSearchParams(search);
    // OAuth callback lands on `/` — keep first-login plan sync on Plan.
    const target = params.get('login') === 'success' ? '/plan' : '/calendar';
    return <Navigate to={{ pathname: target, search }} replace />;
}

function SemesterDataGateWrapper() {
    return (
        <SemesterDataGate>
            <Outlet />
        </SemesterDataGate>
    );
}

function AppChrome() {
    const { pathname } = useLocation();
    const isAdmin = pathname.startsWith('/admin');

    return (
        <div className="App">
            {!isAdmin && (
                <header>
                    <Navbar />
                </header>
            )}
            <main>
                <Routes>
                    <Route path="/admin" element={<AdminGate />}>
                        <Route element={<AdminShell />}>
                            <Route index element={<AdminDashboard />} />
                            <Route path="feedback" element={<AdminFeedback />} />
                            <Route path="reports" element={<AdminReports />} />
                        </Route>
                    </Route>
                    <Route element={<SemesterDataGateWrapper />}>
                        <Route path="/" element={<RootRedirect />} />
                        <Route path="/plan" element={<Generator />} />
                        <Route path="/empty-halls" element={<EmptyLectureHalls />} />
                        <Route path="/calendar" element={<MyCalendar />} />
                        <Route path="/my-calendar" element={<Navigate to="/calendar" replace />} />
                        <Route path="/course-explorer" element={<CourseExplorer />} />
                        <Route path="/course/:courseCode/roster" element={<CourseRoster />} />
                        <Route path="/course/:courseCode/:semesterCode" element={<CourseOffering />} />
                        <Route path="/course/:courseCode" element={<CourseDetails />} />
                        <Route path="/professors" element={<ProfessorExplorer />} />
                        <Route path="/professor/:email" element={<ProfessorDetail />} />
                        <Route path="/students" element={<StudentExplorer />} />
                        <Route path="/student/:kerberos" element={<StudentDetail />} />
                        <Route path="/rooms" element={<RoomSchedules />} />
                        <Route path="/rooms/:roomSlug" element={<RoomDetail />} />
                        <Route path="/feedback" element={<Feedback />} />
                    </Route>
                </Routes>
            </main>
            {!isAdmin && (
                <footer>
                    <Footer />
                </footer>
            )}
        </div>
    );
}

function App() {
    return (
        <ThemeProvider>
            <AuthProvider>
                <SemesterDataProvider>
                    <BrowserRouter>
                        <AppChrome />
                    </BrowserRouter>
                </SemesterDataProvider>
            </AuthProvider>
        </ThemeProvider>
    );
}

export default App;
