// FpgaModel.js

var fpgaAddressModel = [
    {
        label: "TA",
        mux_idx: 1,
        channel: 4,
        i2c_addr: 0x41,
        functions: [
            { name: "PULSE WIDTH", desc: "Pulse Width", start_address: 0x00, data_size: "24B", direction: "RW" },
            { name: "PERIOD", desc: "Period", start_address: 0x03, data_size: "24B", direction: "RW" },
            { name: "CURRENT DRV", desc: "Current Drive", start_address: 0x06, data_size: "16B", direction: "RW" },
            { name: "CURRENT LIMIT", desc: "Current Limit", start_address: 0x08, data_size: "16B", direction: "RW" },
            { name: "PWM MON CL", desc: "PWM Monitor Current Limit", start_address: 0x0A, data_size: "16B", direction: "RW" },
            { name: "CW MON CL", desc: "CW Monitor Current Limit", start_address: 0x0C, data_size: "16B", direction: "RW" },
            { name: "STATIC CTL", desc: "Static Control", start_address: 0x20, data_size: "16B", direction: "RW" },
            { name: "DYNAMIC CTL", desc: "Dynamic Control", start_address: 0x22, data_size: "16B", direction: "RW" }
        ]
    },
    {
        label: "Seed",
        mux_idx: 1,
        channel: 5,
        i2c_addr: 0x41,
        functions: [
            { name: "DDS CTRL", desc: "DDS Control", start_address: 0x00, data_size: "16B", direction: "RW" },
            { name: "DDS GAIN", desc: "DDS Gain", start_address: 0x02, data_size: "16B", direction: "RW" },
            { name: "CW GAIN", desc: "CW Gain", start_address: 0x04, data_size: "16B", direction: "RW" },
            { name: "DDS CL", desc: "DDS Current Limit", start_address: 0x06, data_size: "16B", direction: "RW" },
            { name: "CW CL", desc: "CW Current Limit", start_address: 0x08, data_size: "16B", direction: "RW" },
            { name: "ADC DDS CL", desc: "ADC DDS Current Limit", start_address: 0x0A, data_size: "16B", direction: "RW" },
            { name: "ADC CW CL", desc: "ADC CW Current Limit", start_address: 0x0C, data_size: "16B", direction: "RW" },
            { name: "ADC CD", desc: "ADC Current Data", start_address: 0x0E, data_size: "16B", direction: "RD" },
            { name: "ADC VD", desc: "ADC Voltage Data", start_address: 0x10, data_size: "16B", direction: "RD" },
            { name: "STATUS", desc: "Status", start_address: 0x10, data_size: "8B", direction: "RD" },
            { name: "STATIC CTRL", desc: "Static Control", start_address: 0x20, data_size: "16B", direction: "RW" },
            { name: "DYNAMIC CTRL", desc: "Dynamic Control", start_address: 0x22, data_size: "16B", direction: "WR" }
        ]
    },
    {
        label: "Safety EE",
        mux_idx: 1,
        channel: 6,
        i2c_addr: 0x41,
        functions: [
            { name: "PULSE WIDTH LL", desc: "Pulse Width Lower Limit", start_address: 0x00, data_size: "32B", direction: "RW" },
            { name: "PULSE WIDTH UL", desc: "Pulse Width Upper Limit", start_address: 0x04, data_size: "32B", direction: "RW" },
            { name: "RATE LL", desc: "Rate Lower Limit", start_address: 0x08, data_size: "32B", direction: "RW" },
            { name: "RATE UL", desc: "Rate Upper Limit", start_address: 0x0C, data_size: "32B", direction: "RW" },
            { name: "DRIVE CL", desc: "Drive Current Limit", start_address: 0x10, data_size: "16B", direction: "RW" },
            { name: "PWM CURRENT", desc: "PWM Drive Current", start_address: 0x12, data_size: "16B", direction: "RW" },
            { name: "CW CURRENT", desc: "CW Drive Current", start_address: 0x14, data_size: "16B", direction: "RW" },
            { name: "PWM MONITOR CL", desc: "PWM Monitor Current Limit", start_address: 0x16, data_size: "16B", direction: "RW" },
            { name: "CW MONITOR CL", desc: "CW Monitor Current Limit", start_address: 0x18, data_size: "16B", direction: "RW" },
            { name: "STATIC CTRL", desc: "Static control bits", start_address: 0x20, data_size: "16B", direction: "RW" },
            { name: "DYNAMIC CTRL", desc: "Dynamic control bits", start_address: 0x22, data_size: "16B", direction: "WR" }
        ]
    },
    {
        label: "Safety OPT",
        mux_idx: 1,
        channel: 7,
        i2c_addr: 0x41,
        functions: [
            { name: "PULSE WIDTH LL", desc: "Pulse Width Lower Limit", start_address: 0x00, data_size: "32B", direction: "RW" },
            { name: "PULSE WIDTH UL", desc: "Pulse Width Upper Limit", start_address: 0x04, data_size: "32B", direction: "RW" },
            { name: "RATE LL", desc: "Rate Lower Limit", start_address: 0x08, data_size: "32B", direction: "RW" },
            { name: "RATE UL", desc: "Rate Upper Limit", start_address: 0x0C, data_size: "32B", direction: "RW" },
            { name: "DRIVE CL", desc: "Drive Current Limit", start_address: 0x10, data_size: "16B", direction: "RW" },
            { name: "PWM CURRENT", desc: "PWM Drive Current", start_address: 0x12, data_size: "16B", direction: "RW" },
            { name: "CW CURRENT", desc: "CW Drive Current", start_address: 0x14, data_size: "16B", direction: "RW" },
            { name: "PWM MONITOR CL", desc: "PWM Monitor Current Limit", start_address: 0x16, data_size: "16B", direction: "RW" },
            { name: "CW MONITOR CL", desc: "CW Monitor Current Limit", start_address: 0x18, data_size: "16B", direction: "RW" },
            { name: "STATIC CTRL", desc: "Static control bits", start_address: 0x20, data_size: "16B", direction: "RW" }
        ]
    }
];
