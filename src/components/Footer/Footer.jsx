import React from 'react';
import './Footer.css';

export default function Footer() {
    const year = new Date().getFullYear();
    return (
        <div className="footer">
            <div className="footer__inner">
                <span className="footer__meta">
                    <span className="footer__mark" aria-hidden="true" />
                    IIT Delhi Timetable · {year}
                </span>
                <span className="footer__credit">
                    Built by Prashant
                    <a href="mailto:prashant@devclub.in" className="footer__link">prashant@devclub.in</a>
                </span>
            </div>
        </div>
    );
}
