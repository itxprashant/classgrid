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
