piDomainMap = [
  {
    'product': 'marketing',
    'cssText': '#pulse_feedback_tab {'+
      'position: fixed;'+
      'transform: rotate(-90deg);'+
      'right: -10px;'+
      'transform-origin: 100% 100%;'+
      'padding: 10px 25px 15px;'+
      'color: white;'+
      'text-transform: uppercase;'+
      'text-decoration: none;'+
      'font-size: 14px;'+
      'font-family: HelveticaNeue-CondensedBold,HelveticaNeueBoldCondensed,HelveticaNeue-Bold-Condensed,"Helvetica Neue Bold Condensed","Roboto Condensed",Sans-serif;'+
      'font-weight: normal;'+
      'letter-spacing: normal;'+
      'cursor: pointer;'+
      'z-index: 600;'+
      'border: 1px solid #ffffff;'+
    '}'
    +
    '@media only screen and (min-width: 769px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'top: 73%;'+
      '}'+
      '#pulse_feedback_tab:hover {'+
        'background-color: #ff3600;'+
        'right: 0px;'+
      '}'+
    '}'
    +
    '@media only screen and (min-width: 426px) and (max-width: 768px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'top: 70%;'+
      '}'+
    '}'
    +
    '@media only screen and (max-width: 425px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'padding: 8px 20px 15px;'+
        'top: 68%;'+
      '}'+
    '}',
    'domains': [
      {
        'domain': 'global-bobcat-com-preview.dibhids.net',
        'comparitor': directComparitor,
      },
      {
        'domain': 'www.bobcat.com',
        'comparitor': directComparitor,
      },
    ]
  },
  {
    'product': 'owners',
    'cssText': '#pulse_feedback_tab {'+
      'box-shadow: 0px 0px 2px gray;' +
      'position: fixed;'+
      'transform: rotate(-90deg);'+
      'right: -10px;'+
      'transform-origin: 100% 100%;'+
      'padding: 10px 25px 15px;'+
      'color: white;'+
      'text-transform: uppercase;'+
      'text-decoration: none;'+
      'font-size: 14px;'+
      'font-family: HelveticaNeue-CondensedBold,HelveticaNeueBoldCondensed,HelveticaNeue-Bold-Condensed,"Helvetica Neue Bold Condensed","Roboto Condensed",Sans-serif;'+
      'font-weight: normal;'+
      'letter-spacing: normal;'+
      'cursor: pointer;'+
      'z-index: 600;'+
    '}'
    +
    '@media only screen and (min-width: 769px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'top: 50%;'+
      '}'+
      '#pulse_feedback_tab:hover {'+
        'background-color: #ff3600;'+
        'right: 0px;'+
      '}'+
    '}'
    +
    '@media only screen and (min-width: 426px) and (max-width: 768px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'top: 70%;'+
      '}'+
    '}'
    +
    '@media only screen and (max-width: 425px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'padding: 8px 20px 15px;'+
        'top: 68%;'+
      '}'+
    '}',
    'domains': [
      {
        'domain': 'new.my.bobcat.com',
        'comparitor': directComparitor,
      },
      {
        'domain': 'my.bobcat.com',
        'comparitor': directComparitor,
      },
      {
        'domain': 'my-bobcat2.qa.dice-tools.com',
        'comparitor': directComparitor,
      },
      {
        'domain': 'my-bobcat.dev.dice-tools.com',
        'comparitor': wcComparitor,
        'product': 'owners'
      },
    ]
  },
  {
    'product': 'dealers',
    'cssText': '#pulse_feedback_tab {'+
      'box-shadow: 0px 0px 2px gray;' +
      'position: fixed;'+
      'transform: rotate(-90deg);'+
      'right: -10px;'+
      'transform-origin: 100% 100%;'+
      'padding: 10px 25px 15px;'+
      'color: white;'+
      'text-transform: uppercase;'+
      'text-decoration: none;'+
      'font-size: 14px;'+
      'font-family: HelveticaNeue-CondensedBold,HelveticaNeueBoldCondensed,HelveticaNeue-Bold-Condensed,"Helvetica Neue Bold Condensed","Roboto Condensed",Sans-serif;'+
      'font-weight: normal;'+
      'letter-spacing: normal;'+
      'cursor: pointer;'+
      'z-index: 600;'+
    '}'
    +
    '@media only screen and (min-width: 769px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'top: 50%;'+
      '}'+
      '#pulse_feedback_tab:hover {'+
        'background-color: #ff3600;'+
        'right: 0px;'+
      '}'+
    '}'
    +
    '@media only screen and (min-width: 426px) and (max-width: 768px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'top: 70%;'+
      '}'+
    '}'
    +
    '@media only screen and (max-width: 425px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'padding: 8px 20px 15px;'+
        'top: 68%;'+
      '}'+
    '}',
    'domains': [
      {
        'domain': 'dealer.bobcat.com',
        'comparitor': directComparitor,
        'product': 'dealers'
      },
      {
        'domain': 'bobcatdealernet.dev.dice-tools.com',
        'comparitor': wcComparitor,
        'product': 'dealers'
      },
      {
        'domain': 'bobcatdealernet.qa.dice-tools.com',
        'comparitor': directComparitor,
        'product': 'dealers'
      }
    ]
  }
];



piDomainMap = [
  {
    'product': 'marketing',
    'cssText': '#pulse_feedback_tab {'+
      'position: fixed;'+
      'transform: rotate(-90deg);'+
      'right: -10px;'+
      'transform-origin: 100% 100%;'+
      'padding: 10px 25px 15px;'+
      'color: white;'+
      'text-transform: uppercase;'+
      'text-decoration: none;'+
      'font-size: 14px;'+
      'font-family: HelveticaNeue-CondensedBold,HelveticaNeueBoldCondensed,HelveticaNeue-Bold-Condensed,"Helvetica Neue Bold Condensed","Roboto Condensed",Sans-serif;'+
      'font-weight: normal;'+
      'letter-spacing: normal;'+
      'cursor: pointer;'+
      'z-index: 600;'+
      'border: 1px solid #ffffff;'+
    '}'
    +
    '@media only screen and (min-width: 769px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'top: 73%;'+
      '}'+
      '#pulse_feedback_tab:hover {'+
        'background-color: #ff3600;'+
        'right: 0px;'+
      '}'+
    '}'
    +
    '@media only screen and (min-width: 426px) and (max-width: 768px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'top: 70%;'+
      '}'+
    '}'
    +
    '@media only screen and (max-width: 425px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'padding: 8px 20px 15px;'+
        'top: 68%;'+
      '}'+
    '}',
    'domains': [
      {
        'domain': 'global-bobcat-com-preview.dibhids.net',
        'comparitor': directComparitor,
      },
      {
        'domain': 'www.bobcat.com',
        'comparitor': directComparitor,
      },
    ]
  },
  {
    'product': 'owners',
    'cssText': '#pulse_feedback_tab {'+
      'box-shadow: 0px 0px 2px gray;' +
      'position: fixed;'+
      'transform: rotate(-90deg);'+
      'right: -10px;'+
      'transform-origin: 100% 100%;'+
      'padding: 10px 25px 15px;'+
      'color: white;'+
      'text-transform: uppercase;'+
      'text-decoration: none;'+
      'font-size: 14px;'+
      'font-family: HelveticaNeue-CondensedBold,HelveticaNeueBoldCondensed,HelveticaNeue-Bold-Condensed,"Helvetica Neue Bold Condensed","Roboto Condensed",Sans-serif;'+
      'font-weight: normal;'+
      'letter-spacing: normal;'+
      'cursor: pointer;'+
      'z-index: 600;'+
    '}'
    +
    '@media only screen and (min-width: 769px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'top: 50%;'+
      '}'+
      '#pulse_feedback_tab:hover {'+
        'background-color: #ff3600;'+
        'right: 0px;'+
      '}'+
    '}'
    +
    '@media only screen and (min-width: 426px) and (max-width: 768px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'top: 70%;'+
      '}'+
    '}'
    +
    '@media only screen and (max-width: 425px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'padding: 8px 20px 15px;'+
        'top: 68%;'+
      '}'+
    '}',
    'domains': [
      {
        'domain': 'new.my.bobcat.com',
        'comparitor': directComparitor,
      },
      {
        'domain': 'my.bobcat.com',
        'comparitor': directComparitor,
      },
      {
        'domain': 'my-bobcat2.qa.dice-tools.com',
        'comparitor': directComparitor,
      },
      {
        'domain': 'my-bobcat.dev.dice-tools.com',
        'comparitor': wcComparitor,
        'product': 'owners'
      },
    ]
  },
  {
    'product': 'dealers',
    'cssText': '#pulse_feedback_tab {'+
      'box-shadow: 0px 0px 2px gray;' +
      'position: fixed;'+
      'transform: rotate(-90deg);'+
      'right: -10px;'+
      'transform-origin: 100% 100%;'+
      'padding: 10px 25px 15px;'+
      'color: white;'+
      'text-transform: uppercase;'+
      'text-decoration: none;'+
      'font-size: 14px;'+
      'font-family: HelveticaNeue-CondensedBold,HelveticaNeueBoldCondensed,HelveticaNeue-Bold-Condensed,"Helvetica Neue Bold Condensed","Roboto Condensed",Sans-serif;'+
      'font-weight: normal;'+
      'letter-spacing: normal;'+
      'cursor: pointer;'+
      'z-index: 600;'+
    '}'
    +
    '@media only screen and (min-width: 769px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'top: 50%;'+
      '}'+
      '#pulse_feedback_tab:hover {'+
        'background-color: #ff3600;'+
        'right: 0px;'+
      '}'+
    '}'
    +
    '@media only screen and (min-width: 426px) and (max-width: 768px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'top: 70%;'+
      '}'+
    '}'
    +
    '@media only screen and (max-width: 425px) {'+
      '#pulse_feedback_tab {'+
        'background-color: #ff3600;'+
        'padding: 8px 20px 15px;'+
        'top: 68%;'+
      '}'+
    '}',
    'domains': [
      {
        'domain': 'dealer.bobcat.com',
        'comparitor': directComparitor,
        'product': 'dealers'
      },
      {
        'domain': 'bobcatdealernet.dev.dice-tools.com',
        'comparitor': wcComparitor,
        'product': 'dealers'
      },
      {
        'domain': 'bobcatdealernet.qa.dice-tools.com',
        'comparitor': directComparitor,
        'product': 'dealers'
      }
    ]
  }
];
