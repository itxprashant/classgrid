import React from 'react';
import './App.css';
import Navbar from './components/Navbar/Navbar';
import Footer from './components/Footer/Footer';
import Generator from './pages/Generator';

import { Routes, Route, BrowserRouter, Navigate } from 'react-router-dom';
import EmptyLectureHalls from './pages/EmptyLectureHalls';
import CourseExplorer from './pages/CourseExplorer';
import CourseDetails from './pages/CourseDetails';
import MyCalendar from './pages/MyCalendar';
import RoomSchedules from './pages/RoomSchedules';
import RoomDetail from './pages/RoomDetail';
import { AuthProvider } from './auth/AuthContext';

function App() {
    return (
        <AuthProvider>
            <BrowserRouter>
                <div className="App">
                    <header>
                        <Navbar />
                    </header>
                    <main>
                        <Routes>
                            <Route path="/" element={<Generator />} />
                            <Route path="/empty-halls" element={<EmptyLectureHalls />} />
                            <Route path="/calendar" element={<MyCalendar />} />
                            <Route path="/my-calendar" element={<Navigate to="/calendar" replace />} />
                            <Route path="/course-explorer" element={<CourseExplorer />} />
                            <Route path="/course/:courseCode" element={<CourseDetails />} />
                            <Route path="/rooms" element={<RoomSchedules />} />
                            <Route path="/rooms/:roomSlug" element={<RoomDetail />} />
                        </Routes>
                    </main>
                    <footer>
                        <Footer />
                    </footer>
                </div>
            </BrowserRouter>
        </AuthProvider>
    );
}

export default App;
