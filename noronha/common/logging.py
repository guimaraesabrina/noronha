# -*- coding: utf-8 -*-

import logging
import pathlib
from datetime import datetime
from kaptan import Kaptan
from logging.handlers import RotatingFileHandler

from noronha.bay.compass import LoggerCompass
from noronha.common.annotations import Configured, Lazy, ready
from noronha.common.conf import LoggerConf
from noronha.common.constants import DateFmt, LoggerConst
from noronha.common.utils import assert_json, assert_str, StructCleaner, order_yaml


class Logger(Configured, Lazy):
    
    conf = LoggerConf
    
    _LOGGER_METHODS = tuple(['debug', 'info', 'warn', 'warning', 'error'])
    
    _LAZY_PROPERTIES = ['level', 'debug_mode']
    
    _TAG_PER_METHOD = {
        'debug': 'DEBUG',
        'info': 'INFO',
        'warning': 'WARN',
        'error': 'ERROR'
    }
    
    _LEVEL_PER_METHOD = {
        'debug': logging.DEBUG,
        'info': logging.INFO,
        'warning': logging.WARN,
        'error': logging.ERROR,
    }
    
    def __init__(self, name: str = LoggerConst.NAME, **kwargs):
        
        self._logger = None
        self.name = name
        self.pretty = False
        self.cleaner = StructCleaner(depth=3)
        self.kwargs = kwargs
    
    def __getattribute__(self, attr_name):
        
        if attr_name in super().__getattribute__('_LOGGER_METHODS'):
            return self.wrap_logger(attr_name)
        else:
            return super().__getattribute__(attr_name)
    
    def setup(self):
        
        if self._logger is not None:
            return self
        
        compass = LoggerCompass(custom_conf=self.kwargs)
        pathlib.Path(compass.log_file_dir).mkdir(parents=True, exist_ok=True)
        handler = RotatingFileHandler(**compass.file_handler_kwargs)
        handler.setLevel(compass.lvl)
        self._logger = logging.getLogger(LoggerConst.NAME)
        self._logger.setLevel(compass.lvl)
        self._logger.addHandler(handler)
        self._logger.propagate = False
        self.pretty = self.conf.get('pretty')
        
        if self.conf.get('join_root'):
            logging.getLogger('root').addHandler(handler)
        
        return self
    
    @property
    def debug_mode(self):
        
        return self.level == logging.DEBUG
    
    @debug_mode.setter
    def debug_mode(self, debug_mode: bool):
        
        if debug_mode:
            self.set_level(logging.DEBUG)
        elif self.debug_mode:
            self.set_level(logging.INFO)
    
    @property
    def level(self):
        
        return self._logger.level
    
    @level.setter
    def level(self, level):
        
        self.set_level(level)
    
    @ready
    def set_level(self, level):
        
        self._logger.setLevel(level)
    
    def wrap_logger(self, log_method):
        
        if log_method == 'warn':
            log_method = 'warning'  # warn is deprecated in Logger module
        
        def wrapper(*args, **kwargs):
            self.log(*args, **kwargs, method=log_method)
        
        return wrapper
    
    @ready
    def log(self, msg, method, force_pretty=False, force_print=False, use_tag=True, tag=None):
        
        lvl = self._LEVEL_PER_METHOD[method]
        tag = (tag or self._TAG_PER_METHOD[method]) if use_tag else None
        msg = self.format(msg, force_pretty=force_pretty, tag=tag)
        getattr(self._logger, method)(msg)
        
        if lvl >= self._logger.level or force_print:
            print(msg)
    
    def echo(self, msg):
        
        self.log(msg, method='info', force_pretty=True, force_print=True, use_tag=False)
    
    def profile(self, msg):
        
        self.log(msg, method='debug', force_pretty=True, use_tag=True, tag='PROFILE')
    
    def format(self, msg, force_pretty=False, tag=None):
        
        if not self.pretty and not force_pretty:
            return msg
        elif isinstance(msg, (list, tuple)):
            return assert_json(msg, indent=4)
        elif hasattr(msg, 'pretty'):
            msg = getattr(msg, 'pretty')()
        
        if isinstance(msg, dict):
            clean_dyct = self.cleaner(msg)
            kaptan = Kaptan().import_config(clean_dyct)
            yaml = kaptan.export(handler=LoggerConst.PRETTY_FMT, explicit_start=True)
            return order_yaml(yaml)
        
        msg = assert_str(msg, allow_none=True)
        
        if tag is None:
            return msg
        else:
            return '{ts} - {tag} - {msg}'.format(
                ts=datetime.now().strftime(DateFmt.READABLE),
                tag=tag,
                msg=msg
            )


LOG = Logger()
