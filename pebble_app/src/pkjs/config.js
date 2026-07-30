module.exports = [
  {
    "type": "heading",
    "defaultValue": "Ripple Configuration"
  },
  {
    "type": "section",
    "items": [
      {
        "type": "heading",
        "defaultValue": "Connection Settings"
      },
      {
        "type": "input",
        "messageKey": "URL",
        "defaultValue": "",
        "label": "WebSocket URL",
        "attributes": {
          "placeholder": "ws://example.com:8080"
        }
      }
    ]
  },
  {
    "type": "submit",
    "defaultValue": "Save Settings"
  }
];
