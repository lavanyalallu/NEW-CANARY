var synthetics = require('Synthetics');
const log = require('SyntheticsLogger');
const https = require('https');

const apiCanaryBlueprint = async function () {
    // The endpoint object is passed from the templatefile function in main.tf
    const endpoint = JSON.parse('${endpoint_json}');

    const requestOptions = {
        hostname: endpoint.hostname,
        method: endpoint.method || 'GET',
        path: endpoint.path,
        port: 443,
        protocol: 'https:',
        headers: endpoint.headers || {}
    };

    log.info(`Making a ${requestOptions.method} request to https://${requestOptions.hostname}${requestOptions.path}`);

    await synthetics.executeHttpStep('Verify API Endpoint', requestOptions, (response) => {
        if (response.statusCode < 200 || response.statusCode >= 300) {
            throw new Error(`Failed with status code ${response.statusCode}`);
        }
        log.info(`Successfully received status code ${response.statusCode}.`);
    });
};

exports.handler = async () => {
    return await apiCanaryBlueprint();
};