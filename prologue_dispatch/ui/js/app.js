var Dispatch = {};

// State
Dispatch.active = true;
Dispatch.alerts = [];
Dispatch.alertTimers = {};
Dispatch.logOpen = false;
Dispatch.largeOpen = false;
Dispatch.callHistory = [];
Dispatch.localCalls = [];
Dispatch.activeFilter = 'all';
Dispatch.myId = 0;
Dispatch.myStatus = 'greenSt';
Dispatch.myPatrol = 'fa-car';
Dispatch.alertUidCounter = 0;

// Status color map
var STATUS_COLORS = {
    greenSt: 'rgb(82,189,20)',
    orangeSt: 'rgb(189,144,20)',
    redSt: 'rgb(189,20,20)',
    offlineSt: 'rgb(40,40,40)',
};

// ================================
// MESSAGE HANDLER
// ================================

$(document).ready(function () {
    window.addEventListener('message', function (event) {
        var d = event.data;
        switch (d.type) {
            case 'newAlert':
                Dispatch.NewAlert(d.call, d.dismissTime, d.measurement);
                break;
            case 'clearAll':
                Dispatch.ClearAll();
                break;
            case 'toggleDispatch':
                Dispatch.active = d.active;
                if (!d.active) Dispatch.ClearAll();
                break;
            case 'respondLatest':
                Dispatch.RespondLatest();
                break;
            case 'toggleLog':
                if (d.open) {
                    Dispatch.OpenLog(d.history || [], d.localCalls || []);
                } else {
                    Dispatch.CloseLog();
                }
                break;
            case 'openLargeDispatch':
                Dispatch.OpenLarge(d.id, d.units);
                break;
            case 'closeLargeDispatch':
                Dispatch.CloseLarge();
                break;
            case 'updateUnits':
                if (Dispatch.largeOpen) Dispatch.RenderUnits(d.units);
                break;
        }
    });
});

// ================================
// ESCAPE - ALWAYS RELEASE FOCUS
// ================================

$(document).on('keydown', function (e) {
    if (e.keyCode === 27) { // ESC
        if (Dispatch.largeOpen) {
            Dispatch.CloseLarge();
            $.post('https://prologue_dispatch/escapePressed', JSON.stringify({}));
        } else if (Dispatch.logOpen) {
            Dispatch.CloseLog();
            $.post('https://prologue_dispatch/escapePressed', JSON.stringify({}));
        }
    }
});

// ================================
// ALERTS
// ================================

Dispatch.NewAlert = function (call, dismissTime, measurement) {
    if (!Dispatch.active) return;

    Dispatch.alertUidCounter++;
    var uid = Dispatch.alertUidCounter;
    call._uid = uid;

    Dispatch.alerts.push(call);
    Dispatch.UpdateActionBar();

    // Build card
    var category = Dispatch.GetCategory(call.category, call.panic);
    var cardClass = 'alert-card';
    if (call.panic) cardClass += ' panic';
    else if (category === 'drugs') cardClass += ' drugs';
    else if (category === 'shooting') cardClass += ' shooting';

    var progressClass = call.panic ? 'red'
        : category === 'drugs' ? 'purple'
        : category === 'shooting' ? 'orange'
        : 'gold';

    var html = '<div class="' + cardClass + '" data-uid="' + uid + '">';
    html += '<div class="alert-header">';
    html += '<span class="alert-title">' + Dispatch.Escape(call.title) + '</span>';
    html += '<span class="alert-counter">' + Dispatch.alerts.length + '</span>';
    html += '</div>';
    html += '<p class="alert-text">' + Dispatch.Escape(call.text) + '</p>';
    html += '<div class="alert-footer">';
    html += '<span class="alert-meta">[ID: ' + call.callId + '] &nbsp; Distance: ' + call.distance + ' ' + (measurement || 'km') + '</span>';

    if (call.color) {
        html += '<div class="alert-color-swatch">';
        html += '<span>Color:</span>';
        html += '<div class="swatch" style="background:rgb(' + Dispatch.Escape(call.color) + ')"></div>';
        html += '</div>';
    }

    html += '</div>';
    html += '<div class="alert-progress ' + progressClass + '" style="width:100%"></div>';
    html += '</div>';

    $('#alert-stack').append(html);

    // Update all counters
    Dispatch.UpdateAlertCounters();

    // Animate progress bar
    var dismissMs = (dismissTime || 5) * 1000;
    var startTime = Date.now();
    var $bar = $('[data-uid="' + uid + '"] .alert-progress');

    var progressInterval = setInterval(function () {
        var elapsed = Date.now() - startTime;
        var pct = Math.max(0, 100 - (elapsed / dismissMs) * 100);
        $bar.css('width', pct + '%');
        if (pct <= 0) clearInterval(progressInterval);
    }, 50);

    // Auto-dismiss
    Dispatch.alertTimers[uid] = setTimeout(function () {
        Dispatch.DismissAlert(uid);
        clearInterval(progressInterval);
    }, dismissMs);
};

Dispatch.DismissAlert = function (uid) {
    var $card = $('[data-uid="' + uid + '"]');
    if ($card.length) {
        $card.addClass('dismissing');
        setTimeout(function () { $card.remove(); }, 400);
    }

    // Remove from alerts array
    Dispatch.alerts = Dispatch.alerts.filter(function (a) { return a._uid !== uid; });

    // Clear timer
    if (Dispatch.alertTimers[uid]) {
        clearTimeout(Dispatch.alertTimers[uid]);
        delete Dispatch.alertTimers[uid];
    }

    Dispatch.UpdateAlertCounters();
    Dispatch.UpdateActionBar();
};

Dispatch.RespondLatest = function () {
    if (Dispatch.alerts.length === 0) return;
    var latest = Dispatch.alerts[Dispatch.alerts.length - 1];

    // Show GPS toast
    Dispatch.ShowGpsToast();

    // Dismiss the alert
    Dispatch.DismissAlert(latest._uid);
};

Dispatch.UpdateAlertCounters = function () {
    var total = Dispatch.alerts.length;
    $('#alert-stack .alert-counter').each(function (i) {
        $(this).text((i + 1) + '/' + total);
    });
};

Dispatch.UpdateActionBar = function () {
    var $bar = $('#action-bar');
    if (Dispatch.alerts.length > 0) {
        // Position below the last alert card
        $bar.removeClass('hidden');
        // Use a slight delay to let DOM update
        setTimeout(function () {
            var $stack = $('#alert-stack');
            var stackBottom = $stack.offset().top + $stack.outerHeight();
            $bar.css('top', (stackBottom + 6) + 'px');
        }, 50);
    } else {
        $bar.addClass('hidden');
    }
};

Dispatch.ClearAll = function () {
    Dispatch.alerts = [];
    Object.keys(Dispatch.alertTimers).forEach(function (k) {
        clearTimeout(Dispatch.alertTimers[k]);
    });
    Dispatch.alertTimers = {};
    $('#alert-stack').empty();
    $('#action-bar').addClass('hidden');
};

// ================================
// GPS TOAST
// ================================

Dispatch.ShowGpsToast = function () {
    var $toast = $('#gps-toast');
    $toast.removeClass('hidden');
    // Reset animation
    $toast[0].style.animation = 'none';
    $toast[0].offsetHeight; // trigger reflow
    $toast[0].style.animation = '';
    setTimeout(function () {
        $toast.addClass('hidden');
    }, 800);
};

// ================================
// DISPATCH LOG (K)
// ================================

Dispatch.OpenLog = function (history, localCalls) {
    Dispatch.logOpen = true;
    Dispatch.callHistory = history || [];
    Dispatch.localCalls = localCalls || [];
    Dispatch.activeFilter = 'all';

    // Reset filter tabs
    $('.filter-tab').removeClass('active');
    $('.filter-tab[data-filter="all"]').addClass('active');

    Dispatch.RenderLog();
    $('#dispatch-log').removeClass('hidden');
};

Dispatch.CloseLog = function () {
    Dispatch.logOpen = false;
    $('#dispatch-log').addClass('hidden');
    $.post('https://prologue_dispatch/closeLog', JSON.stringify({}));
};

Dispatch.RenderLog = function () {
    var calls = Dispatch.callHistory;
    var filter = Dispatch.activeFilter;

    if (filter !== 'all') {
        calls = calls.filter(function (c) {
            return Dispatch.GetCategory(c.category, c.panic) === filter;
        });
    }

    $('#log-count').text(calls.length + ' call' + (calls.length !== 1 ? 's' : '') + (filter !== 'all' ? ' · ' + filter : ''));

    if (calls.length === 0) {
        $('#log-list').html('<div class="log-empty">No calls in this category</div>');
        return;
    }

    var html = '';
    for (var i = 0; i < calls.length; i++) {
        var c = calls[i];
        var cat = Dispatch.GetCategory(c.category, c.panic);
        var itemClass = 'log-item';
        if (c.panic) itemClass += ' panic';
        else if (cat === 'drugs') itemClass += ' drugs';
        else if (cat === 'shooting') itemClass += ' shooting';
        if (c.responded) itemClass += ' responded';

        var timeStr = c.serverTime ? Dispatch.FormatTime(c.serverTime) : '';

        html += '<div class="' + itemClass + '">';
        html += '<div class="log-item-header">';
        html += '<span class="log-item-title">' + Dispatch.Escape(c.title || 'ALERT') + '</span>';
        html += '<div class="log-item-actions">';
        html += '<span class="log-item-time">' + timeStr + '</span>';

        if (c.responded) {
            html += '<span class="log-responded-badge">✓</span>';
        }

        // GPS button
        if (c.coords) {
            html += '<div class="gps-btn" data-gps-x="' + c.coords.x + '" data-gps-y="' + c.coords.y + '">';
            html += '<i class="fa-solid fa-location-dot"></i> GPS';
            html += '</div>';
        }

        html += '</div></div>';
        html += '<p class="log-item-text">' + Dispatch.Escape(c.text || '') + '</p>';

        if (c.officer) {
            html += '<span class="log-item-officer">Responded: ' + Dispatch.Escape(c.officer) + '</span>';
        }

        html += '</div>';
    }

    $('#log-list').html(html);
};

// Filter tab clicks
$(document).on('click', '.filter-tab', function () {
    var filter = $(this).data('filter');
    Dispatch.activeFilter = filter;
    $('.filter-tab').removeClass('active');
    $(this).addClass('active');
    Dispatch.RenderLog();
});

// GPS button in log
$(document).on('click', '.gps-btn', function () {
    var x = parseFloat($(this).data('gps-x'));
    var y = parseFloat($(this).data('gps-y'));
    var $btn = $(this);

    $.post('https://prologue_dispatch/gpsToCall', JSON.stringify({ x: x, y: y }));

    Dispatch.ShowGpsToast();
    $btn.addClass('flash');
    setTimeout(function () { $btn.removeClass('flash'); }, 800);
});

// Close log button
$(document).on('click', '#log-close-btn', function () {
    Dispatch.CloseLog();
    $.post('https://prologue_dispatch/escapePressed', JSON.stringify({}));
});

// Action bar buttons
$(document).on('click', '#btn-respond', function () {
    if (Dispatch.alerts.length > 0) {
        var latest = Dispatch.alerts[Dispatch.alerts.length - 1];
        $.post('https://prologue_dispatch/respondAlert', JSON.stringify({ callId: latest.callId }));
        Dispatch.RespondLatest();
    }
});

$(document).on('click', '#btn-allcalls', function () {
    // Trigger K keybind callback
    $.post('https://prologue_dispatch/closeLog', JSON.stringify({})); // will trigger the lua toggle
});

// ================================
// LARGE DISPATCH (O)
// ================================

Dispatch.OpenLarge = function (myId, units) {
    Dispatch.largeOpen = true;
    Dispatch.myId = myId;
    Dispatch.myStatus = 'greenSt';
    Dispatch.myPatrol = 'fa-car';

    // Find my data
    for (var i = 0; i < units.length; i++) {
        if (units[i].id === myId) {
            Dispatch.myStatus = units[i].status || 'greenSt';
            Dispatch.myPatrol = units[i].patrol || 'fa-car';
            $('#ld-callsign-input').val(units[i].number || '0A-00');
            break;
        }
    }

    // Apply my status/patrol to controller
    Dispatch.ApplyMyStatus();
    Dispatch.ApplyMyPatrol();

    Dispatch.RenderUnits(units);
    $('#large-dispatch').removeClass('hidden');
};

Dispatch.CloseLarge = function () {
    Dispatch.largeOpen = false;
    $('#large-dispatch').addClass('hidden');
};

Dispatch.RenderUnits = function (units) {
    var html = '';
    for (var i = 0; i < units.length; i++) {
        var u = units[i];
        var isMe = u.id === Dispatch.myId;
        var statusColor = STATUS_COLORS[u.status] || STATUS_COLORS.greenSt;

        html += '<div class="ld-unit' + (isMe ? ' is-me' : '') + '">';
        html += '<div class="ld-unit-inner">';
        html += '<div class="ld-unit-status" style="background-color:' + statusColor + '"></div>';
        html += '<div class="ld-unit-patrol"><i class="fa-solid ' + Dispatch.Escape(u.patrol || 'fa-car') + '"></i></div>';
        html += '<div class="ld-unit-name"><b>' + Dispatch.Escape(u.number || '0A-00') + '</b> - ' + Dispatch.Escape(u.name || 'Unknown') + '</div>';
        if (isMe) {
            html += '<span class="ld-unit-you">YOU</span>';
        }
        html += '</div></div>';
    }
    $('#ld-units-list').html(html);
};

Dispatch.ApplyMyStatus = function () {
    var color = STATUS_COLORS[Dispatch.myStatus] || STATUS_COLORS.greenSt;
    $('#ld-my-status-bar').css('background-color', color);
    $('.status-dot').removeClass('active');
    $('.status-dot[data-status="' + Dispatch.myStatus + '"]').addClass('active');
};

Dispatch.ApplyMyPatrol = function () {
    $('.patrol-icon').removeClass('active');
    $('.patrol-icon[data-patrol="' + Dispatch.myPatrol + '"]').addClass('active');
};

// Status dot clicks
$(document).on('click', '.status-dot', function () {
    Dispatch.myStatus = $(this).data('status');
    Dispatch.ApplyMyStatus();
    $.post('https://prologue_dispatch/updateUserUnit', JSON.stringify({ type: 'status', value: Dispatch.myStatus }));
});

// Patrol icon clicks
$(document).on('click', '.patrol-icon', function () {
    Dispatch.myPatrol = $(this).data('patrol');
    Dispatch.ApplyMyPatrol();
    $.post('https://prologue_dispatch/updateUserUnit', JSON.stringify({ type: 'patrol', value: Dispatch.myPatrol }));
});

// Callsign submit
$(document).on('click', '#ld-callsign-btn', function () {
    Dispatch.SubmitCallsign();
});

$(document).on('keydown', '#ld-callsign-input', function (e) {
    if (e.keyCode === 13) Dispatch.SubmitCallsign();
});

Dispatch.SubmitCallsign = function () {
    var val = $('#ld-callsign-input').val().toUpperCase().trim();
    if (val.length === 0) val = '0A-00';
    $('#ld-callsign-input').val(val);
    $.post('https://prologue_dispatch/updateUserUnit', JSON.stringify({ type: 'number', value: val }));
};

// Close large dispatch
$(document).on('click', '#ld-close-btn', function () {
    $.post('https://prologue_dispatch/escapePressed', JSON.stringify({}));
    Dispatch.CloseLarge();
});

// ================================
// UTILITIES
// ================================

Dispatch.GetCategory = function (category, panic) {
    if (panic) return 'panic';
    if (!category) return 'alert';
    var c = category.toLowerCase();
    if (c === 'shooting') return 'shooting';
    if (c === 'drugs' || c === 'drug') return 'drugs';
    if (c === 'theft') return 'theft';
    return 'alert';
};

Dispatch.Escape = function (str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
};

Dispatch.FormatTime = function (timestamp) {
    var d = new Date(timestamp * 1000);
    var h = d.getHours();
    var m = d.getMinutes();
    var ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h === 0) h = 12;
    return h + ':' + (m < 10 ? '0' : '') + m + ' ' + ampm;
};
