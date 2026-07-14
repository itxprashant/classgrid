/** IITD student ids: aa1234567 (2 letters + 7 digits) or abc123456 (3 letters + 6 digits). */
export const STUDENT_KERBEROS_RE = /^(?:[a-z]{2}[0-9]{7}|[a-z]{3}[0-9]{6})$/;

export function isStudentKerberos(kerberos) {
    return STUDENT_KERBEROS_RE.test((kerberos || '').toLowerCase().trim());
}

/** Branch prefix + entry year from IITD kerberos id (matches BranchAnalytics). */
export function kerberosMeta(kerberos) {
    const id = (kerberos || '').trim();
    const match = id.match(/^([a-z0-9]{3})([0-9]{2})/i);
    if (!match) {
        return { branch: null, entryYear: null };
    }
    return {
        branch: match[1].toUpperCase(),
        entryYear: `20${match[2]}`,
    };
}
