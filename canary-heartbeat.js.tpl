const log = require('SyntheticsLogger');

const heartbeatBlueprint = async function () {
    log.info("Heartbeat canary run successful. This indicates the monitored process is on schedule.");
    // The success of this function is the heartbeat signal.
    // No external calls are needed.
};

exports.handler = async () => {
    return await heartbeatBlueprint();
};