import React from 'react';
import { Link } from 'react-router-dom';
import './Footer.css';

export default function Footer() {
    const year = new Date().getFullYear();
    const siteVersion = process.env.REACT_APP_SITE_VERSION || '1.0.0';
    return (
        <div className="footer">
            <div className="footer__inner">
                <span className="footer__meta">
                    <span className="footer__mark" aria-hidden="true" />
                    IIT Delhi Timetable · {year}
                    <span className="footer__version mono dim">v{siteVersion}</span>
                </span>
                <span className="footer__credit">
                    <Link to="/feedback" className="footer__link">Suggest a feature</Link>
                    Built by Prashant
                    <a href="mailto:prashant@devclub.in" className="footer__link">prashant@devclub.in</a>
                </span>
            </div>
        </div>
    );
}
