import React, { useMemo } from 'react';
import './BranchAnalytics.css';

const COLORS = [
    'oklch(0.62 0.10 195)',
    'oklch(0.60 0.10 80)',
    'oklch(0.58 0.10 40)',
    'oklch(0.55 0.10 290)',
    'oklch(0.62 0.10 145)',
    'oklch(0.58 0.10 20)',
    'oklch(0.55 0.10 240)',
    'oklch(0.60 0.10 100)',
    'oklch(0.58 0.10 350)',
    'oklch(0.62 0.10 170)',
];

export function BranchPieChart({ students }) {
    const data = useMemo(() => {
        const counts = students.reduce((acc, student) => {
            const match = student.id.match(/^([a-z0-9]{3})/i);
            const branch = match ? match[1].toUpperCase() : 'Others';
            acc[branch] = (acc[branch] || 0) + 1;
            return acc;
        }, {});
        return Object.entries(counts)
            .sort((a, b) => b[1] - a[1])
            .map(([name, value], index) => ({
                name,
                value,
                color: COLORS[index % COLORS.length],
            }));
    }, [students]);

    const total = students.length;
    let accumulatedAngle = -90;

    return (
        <div className="branch-analytics branch-analytics--pie">
            <svg viewBox="0 0 100 100" className="branch-analytics__svg" aria-label="Branch distribution">
                {data.map((slice) => {
                    const percentage = slice.value / total;
                    const angle = percentage * 360;
                    const x1 = 50 + 50 * Math.cos((Math.PI * accumulatedAngle) / 180);
                    const y1 = 50 + 50 * Math.sin((Math.PI * accumulatedAngle) / 180);
                    const endAngle = accumulatedAngle + angle;
                    const x2 = 50 + 50 * Math.cos((Math.PI * endAngle) / 180);
                    const y2 = 50 + 50 * Math.sin((Math.PI * endAngle) / 180);
                    const largeArcFlag = angle > 180 ? 1 : 0;
                    const pathData =
                        total === slice.value
                            ? 'M 50 50 m -50 0 a 50 50 0 1 0 100 0 a 50 50 0 1 0 -100 0'
                            : `M 50 50 L ${x1} ${y1} A 50 50 0 ${largeArcFlag} 1 ${x2} ${y2} Z`;
                    accumulatedAngle += angle;
                    return (
                        <path
                            key={slice.name}
                            d={pathData}
                            fill={slice.color}
                            stroke="var(--surface)"
                            strokeWidth="0.8"
                        >
                            <title>{`${slice.name}: ${slice.value} (${(percentage * 100).toFixed(1)}%)`}</title>
                        </path>
                    );
                })}
                <circle cx="50" cy="50" r="30" fill="var(--surface)" />
                <text
                    x="50"
                    y="48"
                    textAnchor="middle"
                    style={{ fontSize: '11px', fill: 'var(--ink-3)', fontFamily: 'var(--font-mono)' }}
                >
                    Total
                </text>
                <text
                    x="50"
                    y="60"
                    textAnchor="middle"
                    style={{ fontSize: '12px', fill: 'var(--ink)', fontFamily: 'var(--font-mono)', fontWeight: 600 }}
                >
                    {total}
                </text>
            </svg>
            <div className="branch-analytics__legend">
                {data.map((item) => (
                    <div key={item.name} className="branch-analytics__legend-item">
                        <span className="branch-analytics__swatch" style={{ backgroundColor: item.color }} />
                        <span className="branch-analytics__legend-label">{item.name}</span>
                        <span className="branch-analytics__legend-value tnum">{item.value}</span>
                    </div>
                ))}
            </div>
        </div>
    );
}

export function BranchYearPivotTable({ students }) {
    const { years, branches, matrix, totals } = useMemo(() => {
        const yearsSet = new Set();
        const branchesSet = new Set();
        const matrix = {};
        students.forEach((student) => {
            const match = student.id.match(/^([a-z0-9]{3})(\d{2})/i);
            const branch = match ? match[1].toUpperCase() : 'Unknown';
            const yearStr = match ? `20${match[2]}` : 'Unknown';
            yearsSet.add(yearStr);
            branchesSet.add(branch);
            if (!matrix[branch]) matrix[branch] = {};
            matrix[branch][yearStr] = (matrix[branch][yearStr] || 0) + 1;
        });
        const years = Array.from(yearsSet).sort();
        const branches = Array.from(branchesSet).sort();
        const totals = {};
        branches.forEach((branch) => {
            totals[branch] = years.reduce((sum, y) => sum + (matrix[branch][y] || 0), 0);
        });
        return { years, branches, matrix, totals };
    }, [students]);

    return (
        <div className="branch-analytics branch-analytics--pivot">
            <table className="branch-analytics__table">
                <thead>
                    <tr>
                        <th className="branch-analytics__corner">Branch</th>
                        {years.map((year) => (
                            <th key={year} className="branch-analytics__year">{year}</th>
                        ))}
                        <th className="branch-analytics__total-head">Total</th>
                    </tr>
                </thead>
                <tbody>
                    {branches.map((branch) => (
                        <tr key={branch}>
                            <td className="branch-analytics__branch">{branch}</td>
                            {years.map((year) => (
                                <td key={year} className="branch-analytics__cell tnum">
                                    {matrix[branch][year] || <span className="muted">·</span>}
                                </td>
                            ))}
                            <td className="branch-analytics__total tnum">{totals[branch]}</td>
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );
}
