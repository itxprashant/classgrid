const { createProxyMiddleware } = require('http-proxy-middleware');

module.exports = function (app) {
    app.use(
        '/LDAP',
        createProxyMiddleware({
            target: 'https://ldapweb.iitd.ac.in',
            changeOrigin: true,
            secure: false, // Ignore SSL certificate errors
        })
    );
};
