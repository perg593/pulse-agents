// Login Form - Selenium Example Script
// see https://github.com/SeleniumHQ/selenium/wiki/WebDriverJs for details
// runs test against http://crossbrowsertesting.github.io/login-form.html

const webdriver = require('selenium-webdriver'),
    By = webdriver.By,
    until = webdriver.until;
var SeleniumServer = require('selenium-webdriver/remote').SeleniumServer;
var request = require('request');
var remoteHub = 'http://hub.crossbrowsertesting.com:80/wd/hub';

var username = "jeremy@ubertags.com";
var authkey = "tagsub3r";

var caps = {
    'name': 'Login Form Example',
    'build': '1.0',
    'browserName': 'Chrome',
    'deviceName': 'Pixel 4',
    'platformVersion': '10.0',
    'platformName': 'Android',
    'deviceOrientation': 'portrait',
    'record_video': 'true',
    'record_network': 'true'
  };

caps.username = username;
caps.password = authkey;

var sessionId = null;


console.log('Connection to the CrossBrowserTesting remote server');
async function main(){
    try{
    var driver = new webdriver.Builder()
                .usingServer(remoteHub)
                .withCapabilities(caps)
                .build();

    console.log('Waiting on the browser to be launched and the session to start');

    await driver.getSession().then(function(session){
        sessionId = session.id_; //need for API calls
        console.log('Session ID: ', sessionId);
        console.log('See your test run at: https://app.crossbrowsertesting.com/selenium/' + sessionId)
    });

    await driver.manage().setTimeouts( { implicit: 100000 } );
    //load your URL
    await driver.get('https://usa.visa.com/?pi_live_preview=true&pi_present=4255');
    try {
      var cookieAccept = await webdriver.findElement(By.css("#CookieReportsBanner > div.wscrBannerContent > div.wscrBannerContentInner > a"));
      await cookieAccept.click();
    } catch (e) {
      console.log("no cookie banner");
    } finally {
      console.log('finally');
    }
    await driver.sleep(5000);
    //take snapshot via cbt api
    await driver.takeSnapshot();

    //quit the driver
    await driver.quit()

    //set the score as passing
    setScore('pass').then(function(result){
        console.log('SUCCESS! set score to pass')
    });
    }
    catch(e){
        webdriverErrorHandler(e, driver)
    }

}

main();


//Call API to set the score
function setScore(score){
    return new Promise((resolve, fulfill)=> {
    var result = { error: false, message: null }

    if (sessionId){

        request({
            method: 'PUT',
            uri: 'https://crossbrowsertesting.com/api/v3/selenium/' + sessionId,
            body: {'action': 'set_score', 'score': score },
            json: true
        },
        function(error, response, body) {
            if (error) {
                result.error = true;
                result.message = error;
            }
            else if (response.statusCode !== 200){
                result.error = true;
                result.message = body;
            }
            else{
                result.error = false;
                result.message = 'success';
            }
        })
        .auth(username, authkey);
    }
    else{
        result.error = true;
        result.message = 'Session Id was not defined';
        deferred.fulfill(result);
    }


        result.error ? fulfill('Fail') : resolve('Pass');
    });
}

//Call API to get a snapshot
webdriver.WebDriver.prototype.takeSnapshot = function() {

    return new Promise((resolve, fulfill)=> {
        var result = { error: false, message: null }

        if (sessionId){
            request.post(
                'https://crossbrowsertesting.com/api/v3/selenium/' + sessionId + '/snapshots',
                function(error, response, body) {
                    if (error) {
                        result.error = true;
                        result.message = error;
                    }
                    else if (response.statusCode !== 200){
                        result.error = true;
                        result.message = body;
                    }
                    else{
                        result.error = false;
                        result.message = 'success';
                    }
                }
            )
            .auth(username,authkey);

        }
        else{
            result.error = true;
            result.message = 'Session Id was not defined';

        }

            result.error ? fulfill('Fail') : resolve('Pass'); //never call reject as we don't need this to actually stop the test
    });
}

//general error catching function
function webdriverErrorHandler(err, driver){

    console.error('There was an unhandled exception! ' + err.message);

    //if we had a session, end it and mark failed
    if (driver && sessionId){
        driver.quit();
        setScore('fail').then(function(result){
            console.log('FAILURE! set score to fail')
        })
    }
}
