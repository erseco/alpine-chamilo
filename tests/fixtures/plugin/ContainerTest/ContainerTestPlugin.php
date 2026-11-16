<?php

class ContainerTestPlugin extends Plugin
{
    protected function __construct()
    {
        parent::__construct('1.0.0', 'alpine-chamilo tests');
    }

    public static function create(): static
    {
        static $instance = null;

        return $instance ??= new static();
    }
}
